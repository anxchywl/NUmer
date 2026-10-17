module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/test/emulator/**/*.test.ts',
    '<rootDir>/test/rules/**/*.test.ts',
  ],
  testTimeout: 30000,
};
