// Cross-repository regression checks against the demo emulators.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import path from 'node:path';

assert.equal(process.env.GCLOUD_PROJECT, 'demo-adfoot');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:/);
assert.match(process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:/);
const mobile = path.resolve(process.env.ADFOOT_MOBILE_REPO ??
  '../../MOBILE/Show-Talent');
const rootRequire = createRequire(path.join(mobile, 'package.json'));
const backendRequire = createRequire(path.join(mobile, 'functions/package.json'));
const {initializeTestEnvironment} = rootRequire('@firebase/rules-unit-testing');
const {ref, uploadBytes, getBytes} = rootRequire('firebase/storage');
const {db, auth, storage} = backendRequire('./lib/firebase.js');
const proofs = backendRequire('./lib/contract_proof_actions.js');
const accounts = backendRequire('./lib/admin_account_actions.js');
const links = backendRequire('./lib/club_links.js');
const enrollment = backendRequire('./lib/club_enrollment.js');
const {mock} = await import('node:test');
assert.equal(db.projectId, 'demo-adfoot');
const env = await initializeTestEnvironment({
  projectId: 'demo-adfoot',
  firestore: {host: '127.0.0.1', port: 8080,
    rules: readFileSync(path.join(mobile, 'firestore.rules'), 'utf8')},
  storage: {host: '127.0.0.1', port: 9199,
    rules: readFileSync(path.join(mobile, 'storage.rules'), 'utf8')},
});
const prefix = `audit-extra-${Date.now()}`;
const adminUid = `${prefix}-admin`;
const uid = `${prefix}-player`;
const clubUid = `${prefix}-club`;
const objectPath = `identityDocuments/${uid}/contractProofs/contract_1.pdf`;
const fileUrl = `gs://${storage.bucket().name}/${objectPath}`;
const profile = (id, role = 'joueur') => ({uid: id, nom: id, role,
  authDisabled: false, estActif: true, emailVerified: true,
  createdByAdmin: true, isMinorProfile: false, profilePublic: true});
const request = data => ({auth: {uid: adminUid, token: {admin: true}}, data});
const output = path.resolve('build/audit-2026-11-20');
mkdirSync(output, {recursive: true});
const findings = {};
const authStub = mock.method(auth, 'getUser', async id => ({
  uid: id, email: 'fixture@example.invalid', emailVerified: true,
  disabled: false, customClaims: {},
}));
try {
  await db.collection('users').doc(adminUid).set(profile(adminUid, 'admin'));
  await db.collection('users').doc(uid).set({...profile(uid),
    contractStatus: 'free', contractStatusProof: {
      status: 'pending', fileUrl, submittedAt: new Date(),
    }});
  const ownerStorage = env.authenticatedContext(uid).storage(`gs://${storage.bucket().name}`);
  const adminStorage = env.authenticatedContext(adminUid, {admin: true})
    .storage(`gs://${storage.bucket().name}`);
  await uploadBytes(ref(ownerStorage, objectPath), new Uint8Array([37, 80, 68, 70, 45, 49]),
    {contentType: 'application/pdf'});
  const response = await proofs.reviewContractStatusProof.run(request({
    uid, expectedFileUrl: fileUrl, status: 'approved', contractStatus: 'free',
  }));
  const storedStatus = (await db.collection('users').doc(uid).get())
    .get('contractStatusProof.status');
  assert.equal(storedStatus, 'approved');
  assert.equal(response.success, true);
  assert.equal(response.data.status, storedStatus);
  findings.verdictResponse = {response, storedStatus,
    portalInterpretsSuccess: response.success === true};

  const bytes = await getBytes(ref(adminStorage, objectPath), 8 * 1024 * 1024);
  assert.equal(bytes.byteLength, 6);
  await db.collection('users').doc(adminUid).update({authDisabled: true});
  const formerAdminStorage = env.authenticatedContext(adminUid)
    .storage(`gs://${storage.bucket().name}`);
  await assert.rejects(getBytes(ref(formerAdminStorage, objectPath)),
    error => error.code === 'storage/unauthorized');
  findings.documentRead = {authorizedBytes: bytes.byteLength,
    sdkReadAfterClaimRemoval: 'storage/unauthorized'};
  await db.collection('users').doc(adminUid).update({authDisabled: false});

  // Exercise the scoped maintenance tool only inside the configured demo bucket.
  const {reviewPrivateDocuments} = backendRequire('./scripts/review-private-document-tokens.cjs');
  const bucket = storage.bucket();
  const agreement = bucket.file('clubAgreements/' + clubUid + '/agreement.pdf');
  await agreement.save(Buffer.from('%PDF-1.4'), {metadata: {
    contentType: 'application/pdf', metadata: {originalName: 'agreement.pdf'},
  }});
  const other = bucket.file('identityDocuments/' + uid + '/passport.png');
  await other.save(Buffer.from([1]), {metadata: {cacheControl: 'private, max-age=120'}});
  const dry = await reviewPrivateDocuments(bucket);
  assert.equal(dry.updated, 0);
  assert.equal(dry.failed, 0);
  assert.ok(dry.needsUpdate >= 2);
  const applied = await reviewPrivateDocuments(bucket, true);
  const [updated] = await agreement.getMetadata();
  assert.equal(updated.cacheControl, 'private, no-store');
  assert.equal(updated.metadata?.originalName, 'agreement.pdf');
  assert.ok(!updated.metadata?.firebaseStorageDownloadTokens);
  assert.equal((await other.getMetadata())[0].cacheControl, 'private, max-age=120');
  const again = await reviewPrivateDocuments(bucket);
  // The emulator stores Firebase download tokens separately from GCS custom
  // metadata. Depending on its version it may retain a token after a GCS PATCH.
  // Report the observed residual independently and require the tool to flag it.
  const [proofMeta] = await bucket.file(objectPath).getMetadata();
  assert.equal(proofMeta.cacheControl, 'private, no-store');
  const residual = proofMeta.metadata?.firebaseStorageDownloadTokens ? 1 : 0;
  assert.equal(applied.failed, residual);
  assert.equal(again.needsUpdate, residual);
  assert.equal(applied.updated + applied.failed, applied.needsUpdate);
  findings.historicalDocuments = {verifiedUpdates: applied.updated,
    residualTokenDetected: residual, emulatorOnly: true};

  // Revoke removes the right before scanning; inject a Firestore scan outage.
  await db.collection('users').doc(clubUid).set({...profile(clubUid, 'club'),
    clubEnrollment: {validUntil: new Date(Date.now() + 86400000), agreementRef: 'AUDIT'}});
  const linkRef = db.collection('player_club_links').doc(`${prefix}-link`);
  await linkRef.set({clubUid, playerUid: uid, status: 'declared', declaredAt: new Date()});
  // Interrupt after a whole page has committed, not only before the first write.
  const extra = db.batch();
  for (let n = 0; n < 26; n++) {
    extra.set(db.collection('player_club_links').doc(prefix + '-before-' + n), {
      clubUid, playerUid: uid, status: 'declared', declaredAt: new Date(),
    });
  }
  await extra.commit();
  let scans = 0;
  const realCollection = db.collection;
  const stub = mock.method(db, 'collection', function(name) {
    if (name === 'player_club_links' && ++scans === 2) throw new Error('Injected scan outage');
    return realCollection.call(this, name);
  });
  try {
    const partial = await accounts.revokeClubEnrollment.run(request({uid: clubUid}));
    assert.equal(partial.data.cascadePending, true);
  } finally { stub.mock.restore(); }
  const revokedProfile = await db.collection('users').doc(clubUid).get();
  const survivingLink = await linkRef.get();
  assert.equal(revokedProfile.get('clubEnrollment'), undefined);
  assert.equal(survivingLink.get('status'), 'declared');
  assert.equal(revokedProfile.get('clubEnrollmentRevocation.counts.cancelled'), 25);
  assert.equal(revokedProfile.get('clubEnrollmentRevocation.state'), 'pending');
  assert.ok(revokedProfile.get('clubEnrollmentRevocationPendingAt'));
  const grant = () => accounts.setClubEnrollmentRight.run(request({
    uid: clubUid, granted: true, agreementRef: 'AUDIT',
    validUntil: new Date(Date.now() + 86400000).toISOString(),
  }));
  await assert.rejects(grant(), error => error.code === 'failed-precondition');
  const cleanup = backendRequire('./lib/cleanup.js');
  await cleanup.retryPendingClubEnrollmentRevocations.run({});
  const recovery = await accounts.revokeClubEnrollment.run(request({uid: clubUid}));
  assert.equal(recovery.data.cascadePending, false);
  assert.equal(recovery.data.cancelled, 27);
  assert.equal((await linkRef.get()).get('status'), 'ended');
  findings.interruptedRevocation = {committedBeforeOutage: 25,
    completedAfterRetry: recovery.data.cancelled};
  await grant();
  await linkRef.set({clubUid, playerUid: uid, clubName: 'Fixture Club',
    status: 'declared', declaredAt: new Date(), declaredUnderAgreementRef: 'AUDIT',
    declaredFacts: {positionCodes: ['ST'], nationalities: ['ML']}});
  const confirmation = await links.confirmClubLink.run({
    auth: {uid, token: {}}, data: {linkId: linkRef.id,
      corrections: {positionCodes: [], nationalities: []}},
  });
  const confirmed = (await db.collection('users').doc(uid).get()).data();
  assert.equal(confirmation.success, true);
  assert.deepEqual(confirmed.nationalities, []);
  assert.deepEqual(confirmed.positionCodes, []);
  findings.clearedFacts = {
    sentCorrections: {positionCodes: [], nationalities: []},
    storedNationalities: confirmed.nationalities,
    storedPositions: confirmed.positionCodes,
    callableSuccess: confirmation.success,
  };

  findings.missingAgreement = enrollment.readClubEnrollmentRight({
    clubEnrollment: {validUntil: new Date(Date.now() + 86400000)},
  });
  // Dates and fixture identifiers are omitted from the evidence where unnecessary.
  writeFileSync(path.join(output, 'backend-contract-reproductions.json'),
    JSON.stringify(findings, null, 2));
  console.log(JSON.stringify(findings, null, 2));
} finally {
  authStub.mock.restore();
  await env.cleanup();
  await db.terminate();
}
