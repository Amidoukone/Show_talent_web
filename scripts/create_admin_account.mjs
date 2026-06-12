#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { randomBytes } from 'node:crypto';

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const DEFAULT_ADMIN_NAME = 'Admin Adfoot';
const DEFAULT_ADMIN_ROLE = 'admin';
const DEFAULT_ADMIN_CLAIM = 'admin';
const ADMIN_CLAIM_KEYS = ['admin', 'platformAdmin', 'superAdmin'];
const SUPPORTED_ADMIN_CLAIMS = new Set(ADMIN_CLAIM_KEYS);
const SUPPORTED_ADMIN_ROLES = new Set(['admin']);

const HELP_TEXT = `
Usage:
  npm.cmd run create-admin -- --email admin@adfoot.com --name "Admin Adfoot" [options]

Options:
  --email <email>              Firebase Auth email for the admin account
  --password <password>        Initial password. If omitted, a temporary password is generated
  --name <displayName>         Name written to Firebase Auth and /users/{uid}
  --claim <claim>              admin | platformAdmin | superAdmin
  --role <role>                Firestore role to write. Default: admin
  --phone <phone>              Optional phone number in E.164 format
  --projectId <projectId>      Optional project guard. Must match the service account project_id
  --serviceAccount <path>      Path to a Firebase Admin SDK service account JSON
  --service-account <path>     Same as --serviceAccount
  --update-password            Also replace the password when the Auth user already exists
  --help                       Show this help

Supported environment variables:
  FIREBASE_SERVICE_ACCOUNT_KEY_PATH
  GOOGLE_APPLICATION_CREDENTIALS
  FIREBASE_PROJECT_ID
  GCLOUD_PROJECT
  ADMIN_EMAIL
  ADMIN_PASSWORD
  ADMIN_NAME
  ADMIN_ROLE
  ADMIN_CLAIM
  ADMIN_PHONE

Example PowerShell:
  $env:FIREBASE_SERVICE_ACCOUNT_KEY_PATH="C:\\secrets\\serviceAccount.json"
  npm.cmd run create-admin -- --email admin@adfoot.com --name "Admin Adfoot" --claim superAdmin

Important:
  google-services.json is not a Firebase Admin SDK service account.
  Admin operator accounts are marked emailVerified=true by design.
  No email verification link is required for admin portal access.
`.trim();

function isBlank(value) {
  return value == null || String(value).trim().length === 0;
}

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      throw new Error(`Unexpected argument: ${token}`);
    }

    const [rawKey, inlineValue] = token.split('=', 2);
    const key = rawKey.slice(2);
    if (!key) {
      throw new Error('Empty option name.');
    }

    if (key === 'help' || key === 'update-password') {
      parsed[key] = true;
      continue;
    }

    if (inlineValue !== undefined) {
      parsed[key] = inlineValue;
      continue;
    }

    const nextToken = argv[index + 1];
    if (nextToken == null || nextToken.startsWith('--')) {
      throw new Error(`Missing value for --${key}.`);
    }

    parsed[key] = nextToken;
    index += 1;
  }

  return parsed;
}

function normalizeEmail(email) {
  return String(email).trim().toLowerCase();
}

function buildTemporaryPassword() {
  return `${randomBytes(12).toString('base64url')}Aa1!`;
}

function resolveServiceAccountPath(args) {
  const candidate =
    args.serviceAccount ??
    args['service-account'] ??
    process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH ??
    process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (isBlank(candidate)) {
    throw new Error(
      'A Firebase Admin SDK service account is required. Set --serviceAccount or FIREBASE_SERVICE_ACCOUNT_KEY_PATH.',
    );
  }

  return path.resolve(String(candidate).trim());
}

function loadServiceAccount(serviceAccountPath) {
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(`Service account file not found: ${serviceAccountPath}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  } catch (error) {
    throw new Error(
      `Unable to read service account JSON: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
  }

  if (
    parsed &&
    typeof parsed === 'object' &&
    'project_info' in parsed &&
    'client' in parsed
  ) {
    throw new Error(
      'The provided file looks like google-services.json. Use a Firebase Admin SDK service_account JSON.',
    );
  }

  if (
    !parsed ||
    typeof parsed !== 'object' ||
    parsed.type !== 'service_account' ||
    typeof parsed.project_id !== 'string' ||
    typeof parsed.client_email !== 'string' ||
    typeof parsed.private_key !== 'string'
  ) {
    throw new Error(
      'Invalid service account. Expected type=service_account, project_id, client_email and private_key.',
    );
  }

  return parsed;
}

function requireNonEmpty(value, label) {
  const normalized = value == null ? '' : String(value).trim();
  if (!normalized) {
    throw new Error(`${label} is required.`);
  }
  return normalized;
}

function resolveRuntimeConfig() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(`${HELP_TEXT}\n`);
    process.exit(0);
  }

  const serviceAccountPath = resolveServiceAccountPath(args);
  const serviceAccount = loadServiceAccount(serviceAccountPath);
  const requestedProjectId =
    args.projectId ?? process.env.FIREBASE_PROJECT_ID ?? process.env.GCLOUD_PROJECT;
  const projectId = isBlank(requestedProjectId)
    ? serviceAccount.project_id
    : String(requestedProjectId).trim();

  if (projectId !== serviceAccount.project_id) {
    throw new Error(
      `Project mismatch: requested ${projectId}, service account belongs to ${serviceAccount.project_id}.`,
    );
  }

  const email = normalizeEmail(
    requireNonEmpty(args.email ?? process.env.ADMIN_EMAIL, 'Admin email'),
  );
  const displayName = requireNonEmpty(
    args.name ?? process.env.ADMIN_NAME ?? DEFAULT_ADMIN_NAME,
    'Admin name',
  );
  const claim = String(
    args.claim ?? process.env.ADMIN_CLAIM ?? DEFAULT_ADMIN_CLAIM,
  ).trim();
  const role = String(args.role ?? process.env.ADMIN_ROLE ?? DEFAULT_ADMIN_ROLE)
    .trim()
    .toLowerCase();
  const phone = args.phone ?? process.env.ADMIN_PHONE;
  const generatedPassword = isBlank(args.password ?? process.env.ADMIN_PASSWORD)
    ? buildTemporaryPassword()
    : null;
  const password = generatedPassword ?? String(args.password ?? process.env.ADMIN_PASSWORD).trim();

  if (!SUPPORTED_ADMIN_CLAIMS.has(claim)) {
    throw new Error(
      `Unsupported admin claim: ${claim}. Use ${ADMIN_CLAIM_KEYS.join(', ')}.`,
    );
  }

  if (!SUPPORTED_ADMIN_ROLES.has(role)) {
    throw new Error('Unsupported Firestore role. Admin operators must use role=admin.');
  }

  return {
    email,
    password,
    displayName,
    claim,
    role,
    phone: isBlank(phone) ? null : String(phone).trim(),
    projectId,
    serviceAccount,
    serviceAccountPath,
    updatePassword: args['update-password'] === true,
    temporaryPasswordGenerated: generatedPassword !== null,
  };
}

function initializeAdminSdk(config) {
  if (getApps().length > 0) {
    return;
  }

  initializeApp({
    credential: cert(config.serviceAccount),
    projectId: config.projectId,
  });
}

function sanitizeClaims(existingClaims, selectedClaim) {
  const nextClaims = {
    ...(existingClaims && typeof existingClaims === 'object' ? existingClaims : {}),
  };

  for (const claim of ADMIN_CLAIM_KEYS) {
    delete nextClaims[claim];
  }

  nextClaims[selectedClaim] = true;
  return nextClaims;
}

async function createOrUpdateAuthUser(auth, config) {
  let userRecord = null;
  let existingUser = false;
  let passwordUpdated = false;

  try {
    userRecord = await auth.getUserByEmail(config.email);
    existingUser = true;
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (!userRecord) {
    userRecord = await auth.createUser({
      email: config.email,
      password: config.password,
      displayName: config.displayName,
      disabled: false,
      emailVerified: true,
      phoneNumber: config.phone ?? undefined,
    });
  } else {
    const updates = {
      email: config.email,
      displayName: config.displayName,
      disabled: false,
      emailVerified: true,
    };

    if (config.phone && userRecord.phoneNumber !== config.phone) {
      updates.phoneNumber = config.phone;
    }

    if (config.updatePassword) {
      updates.password = config.password;
      passwordUpdated = true;
    }

    userRecord = await auth.updateUser(userRecord.uid, updates);
  }

  const nextClaims = sanitizeClaims(userRecord.customClaims, config.claim);
  await auth.setCustomUserClaims(userRecord.uid, nextClaims);
  userRecord = await auth.getUser(userRecord.uid);

  return { userRecord, existingUser, passwordUpdated };
}

async function upsertFirestoreProfile(firestore, userRecord, config) {
  const userRef = firestore.collection('users').doc(userRecord.uid);
  const existingSnapshot = await userRef.get();
  const existingData = existingSnapshot.exists ? existingSnapshot.data() ?? {} : {};
  const emailVerified = userRecord.emailVerified === true;
  const authDisabled = userRecord.disabled === true;

  await userRef.set(
    {
      uid: userRecord.uid,
      nom: config.displayName,
      email: config.email,
      phone: config.phone ?? existingData.phone ?? null,
      role: config.role,
      photoProfil: existingData.photoProfil ?? '',
      estActif: emailVerified && !authDisabled,
      authDisabled,
      emailVerified,
      emailVerifiedAt: emailVerified
        ? existingData.emailVerifiedAt ?? FieldValue.serverTimestamp()
        : null,
      dateInscription:
        existingData.dateInscription ?? FieldValue.serverTimestamp(),
      dernierLogin: existingData.dernierLogin ?? FieldValue.serverTimestamp(),
      followers: existingData.followers ?? 0,
      followings: existingData.followings ?? 0,
      followersList: existingData.followersList ?? [],
      followingsList: existingData.followingsList ?? [],
      profilePublic: false,
      allowMessages: false,
      createdByAdmin: false,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function buildSummary({
  config,
  userRecord,
  existingUser,
  passwordUpdated,
}) {
  return {
    projectId: config.projectId,
    uid: userRecord.uid,
    email: config.email,
    name: config.displayName,
    role: config.role,
    claim: config.claim,
    existingUser,
    passwordUpdated,
    temporaryPasswordGenerated: config.temporaryPasswordGenerated,
    passwordToUse: !existingUser || passwordUpdated ? config.password : null,
    emailVerified: userRecord.emailVerified === true,
    emailVerificationRequired: false,
    authDisabled: userRecord.disabled === true,
    firestoreUserPath: `users/${userRecord.uid}`,
  };
}

async function main() {
  const config = resolveRuntimeConfig();
  initializeAdminSdk(config);

  const auth = getAuth();
  const firestore = getFirestore();

  const { userRecord, existingUser, passwordUpdated } =
    await createOrUpdateAuthUser(auth, config);

  await upsertFirestoreProfile(firestore, userRecord, config);

  process.stdout.write('\n');
  process.stdout.write(
    `${JSON.stringify(
      buildSummary({ config, userRecord, existingUser, passwordUpdated }),
      null,
      2,
    )}\n`,
  );

  if (existingUser && !passwordUpdated) {
    process.stdout.write(
      'Existing Auth user: password was not changed. Add --update-password to replace it.\n',
    );
  }

  process.stdout.write(
    'The admin portal will accept this account when /users/{uid} has role=admin, authDisabled=false and an admin custom claim is present.\n',
  );
  process.stdout.write(
    'No email verification step is required for this admin operator account.\n',
  );
}

main().catch((error) => {
  process.stderr.write('\nAdmin account bootstrap failed.\n');
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
