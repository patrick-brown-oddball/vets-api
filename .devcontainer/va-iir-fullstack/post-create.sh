#!/bin/sh

# this runs at Codespace creation - not part of pre-build

echo "post-create start"
echo "$(date)    post-create start" >> "$HOME/status"

# update the repos
git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git /workspaces/vets-api-mockdata
git clone https://github.com/department-of-veterans-affairs/vets-website.git /workspaces/vets-website

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 14
npm install --global yarn

git -C /workspaces/vets-api-mockdata pull
git -C /workspaces/vets-api pull

mkdir /workspaces/vets-api/.vscode
{
{
  "rubyLsp.rubyVersionManager": "none"
}
} >> /workspaces/vets-api/.vscode/settings.json

bundle install

cd /workspaces/vets-website
yarn install

echo "post-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-create complete" >> "$HOME/status"
