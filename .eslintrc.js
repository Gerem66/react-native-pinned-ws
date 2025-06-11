module.exports = {
  root: true,
  extends: ['@react-native'],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  env: {
    jest: true,
  },
  rules: {
    '@typescript-eslint/func-call-spacing': 'off',
  },
  overrides: [
    {
      files: ['*.ts', '*.tsx'],
      rules: {
        '@typescript-eslint/no-shadow': ['error'],
        'no-shadow': 'off',
        'no-undef': 'off',
        '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
        '@typescript-eslint/func-call-spacing': 'off',
      },
    },
    {
      files: ['jest.setup.js'],
      env: {
        jest: true,
      },
    },
  ],
  ignorePatterns: [
    'dist/',
    'android/build/',
    'ios/build/',
    'node_modules/',
  ],
};
