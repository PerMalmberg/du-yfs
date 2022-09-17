set -e -o pipefail

sudo apt install npm sudo apt lua5.3 liblua5.3-dev luarocks -y
luarocks --local install busted
luarocks --local install luacov
luarocks --local install luacov-html
# Install globally to keep node_modules away from project directory
sudo npm i -g @wolfe-labs/du-luac
# Give us ownership of node_modules
sudo chown -R $USER /usr/local/lib/node_modules

echo 
echo Add this to your PATH: ${HOME}/.luarocks/bin