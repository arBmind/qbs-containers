ARG DISTRO=noble
ARG CLANG_MAJOR=18
# clang source options:
# apt - directly use apt version
# llvm - add llvm distro repo
ARG CLANG_SOURCE=apt
ARG GCC_MAJOR=14
# gcc source options:
# apt - directly use apt version
# ppa - add toolchain ppa
ARG GCC_SOURCE=apt
ARG QT_VERSION=6.7.1
ARG QT_ARCH=linux_gcc_64
ARG QT_MODULES=""
ARG QBS_VERSION="2.3.1"
ARG QBS_URL="https://download.qt.io/official_releases/qbs/${QBS_VERSION}/qbs-linux-x86_64-${QBS_VERSION}.tar.gz"
# Ubuntu lunar
# ARG RUNTIME_APT="libicu72 libgssapi-krb5-2 libdbus-1-3 libpcre2-16-0"
ARG RUNTIME_APT="libicu74 libgssapi-krb5-2 libdbus-1-3 libpcre2-16-0"


# base Qt setup
FROM python:3.10-slim as qt_base
ARG QT_ARCH
ARG QT_VERSION
ARG QT_MODULES
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN pip install aqtinstall

RUN <<INSTALL_7ZIP
  apt update --quiet
  apt-get install --yes --quiet --no-install-recommends \
    p7zip-full \
    libglib2.0-0
  apt-get --yes autoremove
  apt-get clean autoclean
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_7ZIP

RUN <<INSTALL_QT
  mkdir /qt
  cd /qt
  aqt install-qt linux desktop ${QT_VERSION} ${QT_ARCH} -m ${QT_MODULES} --external $(which 7zr)
INSTALL_QT



# base Qbs setup
FROM ubuntu:${DISTRO} AS qbs_base
ARG QBS_URL
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN <<INSTALL_WGET
  apt-get update --quiet
  apt-get upgrade --yes --quiet
  apt-get install --yes --quiet --no-install-recommends \
    ca-certificates \
    wget
  apt-get --yes autoremove
  apt-get clean autoclean
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_WGET

RUN <<INSTALL_QBS
  mkdir -p /opt/qbs
  wget -q -c ${QBS_URL} -O - | tar --strip-components=1 -xz -C /opt/qbs
INSTALL_QBS



# base compiler setup for GCC
FROM ubuntu:${DISTRO} AS gcc_base
ARG DISTRO
ARG GCC_MAJOR
ARG GCC_SOURCE
ARG RUNTIME_APT
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

RUN <<INSTALL_GCC
  apt-get update --quiet
  apt-get upgrade --yes --quiet
  apt-get install --yes --quiet --no-install-recommends \
    libglib2.0-0 \
    apt-transport-https \
    ca-certificates \
    gnupg \
    wget
  if [ "$GCC_SOURCE" = "ppa" ] ; then
    wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add -
    echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list
    apt-get update --quiet
  fi
  apt-get install --yes --quiet --no-install-recommends \
    libstdc++-${GCC_MAJOR}-dev \
    gcc-${GCC_MAJOR} \
    g++-${GCC_MAJOR} \
    ${RUNTIME_APT}
  update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_MAJOR} 100
  c++ --version
  apt-get --yes autoremove
  apt-get clean autoclean
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_GCC



# final qbs-gcc (no Qt)
FROM gcc_base AS qbs-gcc
ARG DISTRO
ARG GCC_MAJOR
ARG QT_VERSION
ARG QT_ARCH
ARG QBS_VERSION

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + Qbs ${QBS_VERSION}"
LABEL org.opencontainers.image.source = "https://github.com/arBmind/qbs-containers"

COPY --from=qbs_base /opt/qbs /opt/qbs
ENV \
  PATH=/opt/qbs/bin:${PATH}

RUN <<SETUP_QBS_GCC
  qbs setup-toolchains --type gcc /usr/bin/g++ gcc
  qbs config defaultProfile gcc
SETUP_QBS_GCC

WORKDIR /project
ENTRYPOINT ["/opt/qbs/bin/qbs"]


# final qbs-gcc-qt (with Qt)
FROM gcc_base AS qbs-gcc-qt
ARG DISTRO
ARG GCC_MAJOR
ARG QT_VERSION
ARG QT_ARCH
ARG QBS_VERSION

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + Qbs ${QBS_VERSION} + Qt ${QT_VERSION}"
LABEL org.opencontainers.image.source = "https://github.com/arBmind/qbs-containers"

COPY --from=qbs_base /opt/qbs /opt/qbs
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/gcc_64 \
  PATH=/qt/${QT_VERSION}/gcc_64/bin:/opt/qbs/bin:${PATH} \
  LD_LIBRARY_PATH=/qt/${QT_VERSION}/gcc_64/lib:${LD_LIBRARY_PATH}

RUN <<SETUP_QBS_GCC_QT
  qbs setup-toolchains --type gcc /usr/bin/g++ gcc
  qbs setup-qt /qt/${QT_VERSION}/gcc_64/bin/qmake qt
  qbs config defaultProfile qt
SETUP_QBS_GCC_QT

WORKDIR /project
ENTRYPOINT ["/opt/qbs/bin/qbs"]


# base compiler setup for Clang
FROM ubuntu:${DISTRO} AS clang_base
ARG DISTRO
ARG CLANG_MAJOR
ARG CLANG_SOURCE
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive
ARG RUNTIME_APT

ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install Clang (https://apt.llvm.org/)
RUN <<INSTALL_CLANG
  apt-get update --quiet
  apt-get upgrade --yes --quiet
  apt-get install --yes --quiet --no-install-recommends \
    libglib2.0-0 \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates
  if [ "$CLANG_SOURCE" = "llvm" ] ; then
    wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    echo "deb http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO}-${CLANG_MAJOR} main" > /etc/apt/sources.list.d/llvm.list
    apt-get update --quiet
  fi
  apt-get install --yes --quiet --no-install-recommends \
    ${RUNTIME_APT} \
    clang-${CLANG_MAJOR} \
    lld-${CLANG_MAJOR} \
    libc++abi-${CLANG_MAJOR}-dev \
    libc++-${CLANG_MAJOR}-dev
    $( [ $CLANG_MAJOR -ge 12 ] echo "libunwind-${CLANG_MAJOR}-dev" )
  update-alternatives --install /usr/bin/cc cc /usr/bin/clang-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.lld-${CLANG_MAJOR} 10
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 20
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.bfd 30
  c++ --version
  apt-get --yes autoremove
  apt-get clean autoclean
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_CLANG



# final qbs-clang (no Qt)
FROM clang_base AS qbs-clang
ARG DISTRO
ARG CLANG_MAJOR
ARG QBS_VERSION
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + Qbs ${QBS_VERSION}"
LABEL org.opencontainers.image.source = "https://github.com/arBmind/qbs-containers"

COPY --from=qbs_base /opt/qbs /opt/qbs
ENV \
  PATH=/opt/qbs/bin:${PATH}

RUN <<SETUP_QBS_CLANG
  qbs setup-toolchains --type clang /usr/bin/clang++ clang
  qbs config defaultProfile clang
SETUP_QBS_CLANG

WORKDIR /project
ENTRYPOINT ["/opt/qbs/bin/qbs"]


FROM clang_base AS clang_libstdcpp_base
ARG DISTRO
ARG GCC_MAJOR
ARG GCC_SOURCE
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN <<INSTALL_LIBSTDCPP
  if [ "$GCC_SOURCE" = "ppa" ] ; then
    wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add -
    echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list
    apt-get update --quiet
  fi
  apt-get install --yes --quiet --no-install-recommends \
    libstdc++-${GCC_MAJOR}-dev
  apt-get --yes autoremove
  apt-get clean autoclean
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_LIBSTDCPP



# final qbs-clang-libstdcpp (no Qt)
FROM clang_libstdcpp_base AS qbs-clang-libstdcpp
ARG DISTRO
ARG CLANG_MAJOR
ARG GCC_MAJOR
ARG QBS_VERSION

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + Libstdc++-${GCC_MAJOR} + Qbs ${QBS_VERSION}"
LABEL org.opencontainers.image.source = "https://github.com/arBmind/qbs-containers"

COPY --from=qbs_base /opt/qbs /opt/qbs
ENV \
  PATH=/opt/qbs/bin:${PATH}

RUN <<SETUP_QBS_CLANG
  qbs setup-toolchains --type clang /usr/bin/clang++ clang
  qbs config defaultProfile clang
SETUP_QBS_CLANG

WORKDIR /project
ENTRYPOINT ["/opt/qbs/bin/qbs"]



# final qbs-clang-qt (with Qt)
FROM clang_libstdcpp_base AS qbs-clang-libstdcpp-qt
ARG DISTRO
ARG CLANG_MAJOR
ARG GCC_MAJOR
ARG QT_VERSION
ARG QT_ARCH
ARG QBS_VERSION

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + Libstdc++-${GCC_MAJOR} + Qbs ${QBS_VERSION} + Qt ${QT_VERSION}"
LABEL org.opencontainers.image.source = "https://github.com/arBmind/qbs-containers"

COPY --from=qbs_base /opt/qbs /opt/qbs
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/gcc_64 \
  PATH=/qt/${QT_VERSION}/gcc_64/bin:/opt/qbs/bin:${PATH} \
  LD_LIBRARY_PATH=/qt/${QT_VERSION}/gcc_64/lib:${LD_LIBRARY_PATH}

RUN <<SETUP_QBS_CLANG_QT
  qbs setup-toolchains --type clang /usr/bin/clang++ clang
  qbs setup-qt /qt/${QT_VERSION}/gcc_64/bin/qmake qt
  qbs config defaultProfile qt
SETUP_QBS_CLANG_QT

WORKDIR /project
ENTRYPOINT ["/opt/qbs/bin/qbs"]
