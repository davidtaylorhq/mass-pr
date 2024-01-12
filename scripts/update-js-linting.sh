#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

# Rename all *.js.es6 to *.js
find . -depth -name "*.js.es6" -exec sh -c 'mv "$1" "${1%.es6}"' _ {} \;

# Remove the old config files
rm -f .eslintrc
rm -f .eslintrc.js
rm -f .prettierrc
rm -f .prettierrc.js
rm -f .template-lintrc.js

rm -f package-lock.json

# Copy these files from skeleton if they do not already exist
if [ -f "plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.template-lintrc.cjs . || true
else # Theme
  cp -vn ../discourse-theme-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.template-lintrc.cjs . || true
fi

# Remove the old transpile_js option
if [ -f "plugin.rb" ]; then
  if grep -q 'transpile_js: true' plugin.rb; then
    ruby -e 'File.write("plugin.rb", File.read("plugin.rb").gsub(/^# transpile_js: true\n/, ""))'
  fi
fi

# Fix i18n helper invocations
find . -name "*.hbs" | xargs sed -i '' 's/{{I18n/{{i18n/g'

# Update all uses of `@class` argument
if [ -n "$(find . -name '*.hbs' -o -name '*.gjs' | xargs grep '@class')" ]; then
  find . -name "*.hbs" -o -name "*.gjs" | xargs sed -i '' 's/@class=/class=/g'
  echo "[update-js-linting] Updated some '@class' args. Please review the changes."
  exit 1
fi

# Use the current linting setup
repo_name=$(git config --get remote.origin.url | grep -o '/\(.*\)' | cut -d'/' -f2)
echo '{
  "name": "'$repo_name'",
  "private": true,
  "devDependencies": {
    "@discourse/lint-configs": "^1.3.4",
    "ember-template-lint": "^5.13.0",
    "eslint": "^8.56.0",
    "prettier": "^2.8.8"
  }
}' > package.json
yarn install

if [ -f "plugin.rb" ]; then
  yarn eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'assets/javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'admin/assets/javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn prettier --write '{assets,admin/assets,test}/**/*.{scss,js,gjs,hbs}' --no-error-on-unmatched-pattern
else # Theme
  yarn prettier --write '{javascripts,desktop,mobile,common,scss,test}/**/*.{scss,js,gjs,hbs}' --no-error-on-unmatched-pattern
fi

# Do an extra check after prettier
if [ -f "plugin.rb" ]; then
  yarn eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

cd ..

../scripts/update-workflows.sh
