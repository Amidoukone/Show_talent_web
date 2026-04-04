import { existsSync, readFileSync } from 'node:fs';
import process from 'node:process';

import admin from 'firebase-admin';

const DEFAULT_PROJECT_ID = 'show-talent-5987d';
const DEFAULT_ADMIN_EMAIL = 'admin@adfoot.com';
const DEFAULT_ADMIN_NAME = 'Admin Adfoot';
const DEFAULT_ADMIN_ROLE = 'admin';
const DEFAULT_ADMIN_CLAIM = 'admin';
const SUPPORTED_ADMIN_CLAIMS = new Set([
  'admin',
  'platformAdmin',
  'superAdmin',
]);

function isBlank(value) {
  return value == null || String(value).trim().length === 0;
}

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index++) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }

    const [rawKey, inlineValue] = token.split('=', 2);
    const key = rawKey.slice(2);
    if (!key) {
      continue;
    }

    if (inlineValue !== undefined) {
      parsed[key] = inlineValue;
      continue;
    }

    const nextToken = argv[index + 1];
    if (nextToken != null && !nextToken.startsWith('--')) {
      parsed[key] = nextToken;
      index++;
      continue;
    }

    parsed[key] = 'true';
  }

  return parsed;
}

function printUsage() {
  console.log(`
Usage:
  npm run create-admin -- --email admin@adfoot.com --password "TempPass123!" [options]

Options:
  --email <email>            E-mail Firebase Auth du compte admin
  --password <password>      Mot de passe temporaire ou definitif
  --name <displayName>       Nom affiche dans Firebase Auth et /users/{uid}
  --claim <claim>            admin | platformAdmin | superAdmin
  --role <role>              Role Firestore a ecrire, par defaut: admin
  --projectId <projectId>    Project ID Firebase cible
  --serviceAccount <path>    Chemin vers un fichier service account JSON
  --help                     Affiche cette aide

Variables d'environnement supportees:
  FIREBASE_SERVICE_ACCOUNT_KEY_PATH
  GOOGLE_APPLICATION_CREDENTIALS
  FIREBASE_PROJECT_ID
  GCLOUD_PROJECT
  ADMIN_EMAIL
  ADMIN_PASSWORD
  ADMIN_NAME
  ADMIN_ROLE
  ADMIN_CLAIM

Exemple PowerShell:
  $env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH="C:\\secrets\\serviceAccount.json"
  npm.cmd run create-admin -- --email admin@adfoot.com --password "TempPass123!" --name "Admin Adfoot" --claim admin
`.trim());
}

function readServiceAccountFromPath(serviceAccountPath) {
  if (!serviceAccountPath) {
    return null;
  }

  if (!existsSync(serviceAccountPath)) {
    throw new Error(
      `Le fichier de service account est introuvable: ${serviceAccountPath}`,
    );
  }

  const rawJson = readFileSync(serviceAccountPath, 'utf8');
  return JSON.parse(rawJson);
}

function resolveRuntimeConfig() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help != null) {
    printUsage();
    process.exit(0);
  }

  const projectId =
    args.projectId ??
    process.env.FIREBASE_PROJECT_ID ??
    process.env.GCLOUD_PROJECT ??
    DEFAULT_PROJECT_ID;

  const email = args.email ?? process.env.ADMIN_EMAIL ?? DEFAULT_ADMIN_EMAIL;
  const password = args.password ?? process.env.ADMIN_PASSWORD;
  const displayName =
    args.name ?? process.env.ADMIN_NAME ?? DEFAULT_ADMIN_NAME;
  const role = args.role ?? process.env.ADMIN_ROLE ?? DEFAULT_ADMIN_ROLE;
  const claim =
    (args.claim ?? process.env.ADMIN_CLAIM ?? DEFAULT_ADMIN_CLAIM).trim();
  const serviceAccountPath =
    args.serviceAccount ??
    process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH ??
    process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (isBlank(email)) {
    throw new Error(
      'L e-mail admin est obligatoire. Passe --email ou ADMIN_EMAIL.',
    );
  }

  if (isBlank(password)) {
    throw new Error(
      'Le mot de passe admin est obligatoire. Passe --password ou ADMIN_PASSWORD.',
    );
  }

  if (isBlank(displayName)) {
    throw new Error('Le nom admin est obligatoire. Passe --name ou ADMIN_NAME.');
  }

  if (isBlank(role)) {
    throw new Error('Le role Firestore est obligatoire. Passe --role ou ADMIN_ROLE.');
  }

  if (!SUPPORTED_ADMIN_CLAIMS.has(claim)) {
    throw new Error(
      `Le claim ${claim} n est pas supporte. Utilise admin, platformAdmin ou superAdmin.`,
    );
  }

  return {
    projectId: projectId.trim(),
    email: email.trim().toLowerCase(),
    password: password.trim(),
    displayName: displayName.trim(),
    role: role.trim(),
    claim,
    serviceAccountPath: isBlank(serviceAccountPath)
      ? null
      : serviceAccountPath.trim(),
  };
}

function initializeAdminSdk(config) {
  const serviceAccount = readServiceAccountFromPath(config.serviceAccountPath);

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.projectId,
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: config.projectId,
  });
}

async function createOrUpdateAuthUser(auth, config) {
  try {
    const existingUser = await auth.getUserByEmail(config.email);
    const updatedUser = await auth.updateUser(existingUser.uid, {
      email: config.email,
      password: config.password,
      displayName: config.displayName,
      disabled: false,
      emailVerified: true,
    });

    return { userRecord: updatedUser, existingUser: true };
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }

    const createdUser = await auth.createUser({
      email: config.email,
      password: config.password,
      displayName: config.displayName,
      disabled: false,
      emailVerified: true,
    });

    return { userRecord: createdUser, existingUser: false };
  }
}

async function upsertFirestoreProfile(firestore, userRecord, config) {
  const userRef = firestore.collection('users').doc(userRecord.uid);
  const existingSnapshot = await userRef.get();
  const existingData = existingSnapshot.exists ? existingSnapshot.data() : null;
  const derivedEstActif = userRecord.emailVerified === true;

  const basePayload = {
    uid: userRecord.uid,
    nom: config.displayName,
    email: config.email,
    role: config.role,
    photoProfil: existingData?.photoProfil ?? '',
    estActif: derivedEstActif,
    estBloque: false,
    authDisabled: false,
    createdByAdmin: existingData?.createdByAdmin ?? false,
    followers: existingData?.followers ?? 0,
    followings: existingData?.followings ?? 0,
    dernierLogin:
      existingData?.dernierLogin ??
      admin.firestore.FieldValue.serverTimestamp(),
  };

  await userRef.set(
    {
      ...basePayload,
      dateInscription:
        existingData?.dateInscription ??
        admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function normalizeAdminClaims(existingClaims, targetClaim) {
  const normalizedClaims = { ...(existingClaims ?? {}) };

  for (const supportedClaim of SUPPORTED_ADMIN_CLAIMS) {
    delete normalizedClaims[supportedClaim];
  }

  normalizedClaims[targetClaim] = true;
  return normalizedClaims;
}

async function applyAdminClaim(auth, userRecord, claim) {
  const latestUserRecord = await auth.getUser(userRecord.uid);
  const existingClaims = latestUserRecord.customClaims ?? {};
  const normalizedClaims = normalizeAdminClaims(existingClaims, claim);
  await auth.setCustomUserClaims(userRecord.uid, normalizedClaims);
}

async function main() {
  const config = resolveRuntimeConfig();
  initializeAdminSdk(config);

  const auth = admin.auth();
  const firestore = admin.firestore();

  const { userRecord, existingUser } = await createOrUpdateAuthUser(
    auth,
    config,
  );

  await applyAdminClaim(auth, userRecord, config.claim);
  await upsertFirestoreProfile(firestore, userRecord, config);

  console.log('');
  console.log(
    existingUser
      ? 'Compte admin existant mis a jour.'
      : 'Compte admin cree.',
  );
  console.log(`Projet Firebase : ${config.projectId}`);
  console.log(`UID : ${userRecord.uid}`);
  console.log(`E-mail : ${config.email}`);
  console.log(`Role Firestore : ${config.role}`);
  console.log(`Custom claim active : ${config.claim}`);
  console.log('');
  console.log(
    'Le dashboard admin acceptera la connexion si /users/{uid} existe, si role == admin, si estBloque == false, si authDisabled == false et si le custom claim est present.',
  );
}

main().catch((error) => {
  console.error('');
  console.error('Echec de creation du compte admin.');
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});


