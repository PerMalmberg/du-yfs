set -e -o pipefail

sudo apt install lua5.3 liblua5.3-dev luarocks
sudo luarocks install busted
sudo luarocks install luacov
sudo luarocks install luacov-html