# Based on: https://github.com/thesourcerer8/OpenSourceTCAD/blob/master/Charon/Dockerfile

FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Australia/Brisbane
# Use Australian Ubuntu archive, https://gist.github.com/magnetikonline/3a841b5268d5581b4422
# If you're not down under, you will probably want to change this to your local mirror
RUN sed --in-place --regexp-extended "s/(\/\/)(archive\.ubuntu)/\1au.\2/" /etc/apt/sources.list

### Install prerequistes
RUN apt update --fix-missing; apt update && apt upgrade -y; \
    apt install -y build-essential cmake gfortran git flex bison \
    wget curl python python-sip-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev hdf5-tools linux-headers-generic \
    libhdf5-dev netcdf-bin cdftools libnetcdf-dev cmake libopenblas-dev libblas-dev libboost-all-dev screen \
    htop git-lfs vim-scripts build-essential libssl-dev ca-certificates gpg wget libmatio-dev

## CMake (TODO use package for this)
WORKDIR /tmp
RUN wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.sh; \
    chmod +x cmake-3.26.4-linux-x86_64.sh; \
    ./cmake-3.26.4-linux-x86_64.sh --skip-license --prefix=/usr/local

## TriBITS
WORKDIR /
RUN git clone https://github.com/TriBITSPub/TriBITS.git; cd TriBITS; git checkout -f 8d696d0bb0
WORKDIR /
RUN mv TriBITS tribits; mkdir tribits/build
WORKDIR tribits/build
RUN cmake ..; make -j24; make install
ENV TRIBITS_BASE_DIR='/tribits'

WORKDIR /
RUN wget https://www.sandia.gov/app/uploads/sites/106/2022/06/charon-distrib-v2_2.tar.gz; \
    mv charon-distrib-v2_2.tar.gz charon-distrib.tar.gz; \
    tar hxvzf charon-distrib.tar.gz
WORKDIR tcad-charon
RUN cd scripts/charonInterpreter/parseGenerator && python3 generateInterpreter.py

## Trilinos
RUN git clone https://github.com/trilinos/Trilinos.git Trilinos; cd Trilinos; git checkout 81e9581a3c5
RUN mkdir build; cd build; cmake -DTrilinos_ENABLE_ALL_PACKAGES=ON -DCMAKE_INSTALL_PREFIX=/usr/local/ ..; \
    cmake -DTPL_ENABLE_Matio=OFF -DCMAKE_INSTALL_PREFIX=/usr/local/ .; \
    make -j$(nproc); \
    make install

## Charon
# TODO do we actually need the fixed cmake?
COPY CharonFixedCMakeLists.txt /tcad-charon/test/nightlyTests/particleStrike/CMakeLists.txt.new
RUN cp /tcad-charon/test/nightlyTests/particleStrike/CMakeLists.txt.new /tcad-charon/test/nightlyTests/particleStrike/CMakeLists.txt
WORKDIR /tcad-charon/scripts/build/all
RUN mkdir src
RUN mkdir src/interpreter
RUN cp -r /tcad-charon/scripts/charonInterpreter /tcad-charon/scripts/build/all/src/interpreter/
RUN ls src/interpreter/charonInterpreter
RUN pwd && python3 build_charon.py --debug-level=1
RUN make -j$(nproc)
RUN make install
