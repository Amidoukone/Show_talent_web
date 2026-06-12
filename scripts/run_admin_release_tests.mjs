#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';

const flutterRoot =
  process.env.FLUTTER_ROOT ?? process.env.FLUTTER_HOME ?? 'C:\\Flutter\\src\\flutter';
const dartExecutable = path.join(
  flutterRoot,
  'bin',
  'cache',
  'dart-sdk',
  'bin',
  process.platform === 'win32' ? 'dart.exe' : 'dart',
);
const flutterToolsSnapshot = path.join(
  flutterRoot,
  'bin',
  'cache',
  'flutter_tools.snapshot',
);
const flutterToolsPackageConfig = path.join(
  flutterRoot,
  'packages',
  'flutter_tools',
  '.dart_tool',
  'package_config.json',
);

const groups = [
  {
    name: 'Environment and release guardrails',
    tests: [
      'test/app_environment_test.dart',
      'test/admin_release_guardrails_test.dart',
    ],
  },
  {
    name: 'Managed account services',
    tests: [
      'test/managed_account_service_test.dart',
      'test/managed_account_provision_result_test.dart',
    ],
  },
  {
    name: 'Managed account widget',
    tests: ['test/managed_accounts_widget_test.dart'],
  },
  {
    name: 'User management widget',
    tests: ['test/user_management_widget_test.dart'],
  },
];

for (const group of groups) {
  process.stdout.write(`\n==> ${group.name}\n`);

  const result = spawnSync(
    dartExecutable,
    [
      `--packages=${flutterToolsPackageConfig}`,
      flutterToolsSnapshot,
      'test',
      ...group.tests,
    ],
    {
      stdio: 'inherit',
      shell: false,
    },
  );

  if (result.error) {
    process.stderr.write(`Unable to run Flutter tests: ${result.error.message}\n`);
    process.exitCode = 1;
    break;
  }

  if (result.status !== 0) {
    process.exitCode = result.status ?? 1;
    break;
  }
}
