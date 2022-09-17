set -e -o pipefail

sudo apt install npm sudo apt lua5.3 liblua5.3-dev luarocks -y
luarocks --local install busted
luarocks --local install luacov
luarocks --local install luacov-html
cd ~
npm i @wolfe-labs/du-luac

echo 
echo Add this to your PATH: ${HOME}/.luarocks/bin