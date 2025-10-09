local M = {}

M.FLAT_CONFIG_FILENAMES = {
  'eslint.config.js',
  'eslint.config.mjs',
  'eslint.config.cjs',
  'eslint.config.ts',
  'eslint.config.mts',
  'eslint.config.cts',
}

M.LEGACY_CONFIG_FILENAMES = {
  '.eslintrc',
  '.eslintrc.js',
  '.eslintrc.cjs',
  '.eslintrc.mjs',
  '.eslintrc.json',
  '.eslintrc.yaml',
  '.eslintrc.yml',
}

M.WATCHED_CONFIG_FILENAMES = vim.list_extend(vim.deepcopy(M.FLAT_CONFIG_FILENAMES), M.LEGACY_CONFIG_FILENAMES)

return M
