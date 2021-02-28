FROM debian:stable

RUN apt-get update -y
RUN apt-get install build-essential pkg-config libffi-dev libgmp-dev -y
RUN apt-get install libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev -y
RUN apt-get install make g++ tmux git jq wget libncursesw5 libtool autoconf -y

# Install Cabal

RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
RUN tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
RUN rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig
RUN mkdir -p ~/.local/bin
RUN mv cabal ~/.local/bin/

RUN echo $PATH

RUN ~/.local/bin/cabal update
RUN ~/.local/bin/cabal --version

# Download and install GHC
RUN wget https://downloads.haskell.org/~ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz 
RUN tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz 
RUN rm ghc-8.10.2-x86_64-deb9-linux.tar.xz
RUN cd ghc-8.10.2 && ./configure && make install

# Install Libsodium
ENV LD_LIBRARY_PATH "/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH "/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

RUN git clone https://github.com/input-output-hk/libsodium
RUN cd libsodium && git checkout 66f017f1 && ./autogen.sh && ./configure && make && make install

# Cardano Source Code

RUN git clone https://github.com/input-output-hk/cardano-node.git

WORKDIR /cardano-node

RUN git fetch --all --tags && git checkout tags/1.24.2
RUN ~/.local/bin/cabal clean
RUN ~/.local/bin/cabal update
RUN ~/.local/bin/cabal build all

RUN cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.24.2/x/cardano-node/build/cardano-node/cardano-node ~/.local/bin/
RUN cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.24.2/x/cardano-cli/build/cardano-cli/cardano-cli ~/.local/bin/


# Run cardano-node

RUN mkdir -p relay
WORKDIR /relay

RUN apt-get install curl -y

ENV NODE_CONFIG "testnet"

RUN export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g') && wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-byron-genesis.json && wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-topology.json && wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-shelley-genesis.json && wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-config.json 

RUN  ~/.local/bin/cardano-node run \
 --topology testnet-topology.json \
 --database-path db \
 --socket-path db/node.socket \
 --host-addr 0.0.0.0 \
 --port 3001 \
 --config testnet-config.json