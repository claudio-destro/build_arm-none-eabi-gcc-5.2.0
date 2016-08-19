#!/bin/bash

# https://solarianprogrammer.com/2015/05/01/compiling-gcc-5-mac-os-x/
# http://cygwin.wikia.com/wiki/How_to_install_a_newer_version_of_GCC

SUDO=""

#############################################################################

TARGET="arm-none-eabi"

# https://sourceware.org/bugzilla/show_bug.cgi?id=19222
BINUTILS_VERSION="binutils-2.25"

NEWLIB_VERSION="newlib-2.2.0.20151023"

GCC_VERSION="gcc-5.2.0"

GMP_VERSION="gmp-6.1.0"
MPFR_VERSION="mpfr-3.1.3"
MPC_VERSION="mpc-1.0.2"
ISL_VERSION="isl-0.14"

APACHE_ANT_VERSION="apache-ant-1.9.6"
GIT_VERSION="2.4.8"

MAKE_OPTIONS="-j4"
CONFIGURE_OPTIONS="--enable-interwork --with-float=soft --disable-nls --disable-shared"

#############################################################################

BASE="$HOME"

PREFIX="$BASE/opt/local"
GCC_PREFIX="$PREFIX"
GMP_PREFIX="$PREFIX"
MPFR_PREFIX="$PREFIX"
MPC_PREFIX="$PREFIX"
ISL_PREFIX="$PREFIX"

TARGET_PREFIX="$PREFIX"
TARGET_GCC_PREFIX="$TARGET_PREFIX"
TARGET_BINUTILS_PREFIX="$TARGET_PREFIX"
TARGET_NEWLIB_PREFIX="$TARGET_PREFIX"

TARGET_ANT_PREFIX="$TARGET_PREFIX"
TARGET_GIT_PREFIX="$TARGET_PREFIX"

case "$OSTYPE" in
	darwin*)
		;;
	linux*) # vagrant init "hashicorp/precise32"
		[ -d "/vagrant/" ] && ln -sf /vagrant/git $HOME/vlab-git
		sudo apt-get -y update || exit 1
		# compiler
		sudo apt-get -y install g++ make m4 texinfo || exit 1
		# git
		sudo apt-get -y install zlibc libcurl4-openssl-dev libexpat-dev gettext || exit 1
		# MAS CU
		sudo apt-get -y install zip
		#
		GCC_PREFIX="/usr"
		;;
	cygwin*)
		GMP_CYGWIN="--enable-static --disable-shared"
		MPFR_CYGWIN="--enable-static --disable-shared"
		MPC_CYGWIN="--enable-static --disable-shared"
		ISL_CYGWIN="--enable-static --disable-shared"
		#
		if [ -n "$BABUN_HOME" ]; then
			pact install gcc-g++ || exit 1
			pact update gcc-core || exit 1
			pact update git || exit 1
		fi
		#
		GCC_PREFIX="/usr"
		;;
esac

mkdir -p "${PREFIX}"

#############################################################################

if [ "$1" = "--debug" ]; then
	function debug() { echo "$@"; }
else
	function debug() { eval "$@" || exit 1; }
fi

function mkbuild() { local dir="build/$1"; mkdir -p "${dir}"; pushd "${dir}" || exit 1; }

function untar() { local tarball="$1*.tar*"; [ -d "$1" ] || tar xvf $tarball; }

#############################################################################

# Apache Ant
#
wget -nc "https://archive.apache.org/dist/ant/binaries/${APACHE_ANT_VERSION}-bin.tar.bz2"
untar "${APACHE_ANT_VERSION}"
mv ${APACHE_ANT_VERSION} $TARGET_ANT_PREFIX
pushd ${TARGET_ANT_PREFIX}
ln -sf "${APACHE_ANT_VERSION}" apache-ant
popd

#############################################################################

# GMP MPFR MPC ISL: do not use gcc/download_prerequisites

# GMP
#
wget -nc "https://gmplib.org/download/gmp/${GMP_VERSION}.tar.bz2"
untar "${GMP_VERSION}"
mkbuild "${GMP_VERSION}"
debug ../../${GMP_VERSION}/configure --prefix="${GMP_PREFIX}" $GMP_CYGWIN
debug make $MAKE_OPTIONS
debug $SUDO make install
popd

# MPFR
#
wget -nc "http://www.mpfr.org/${MPFR_VERSION}/${MPFR_VERSION}.tar.bz2"
untar "${MPFR_VERSION}"
mkbuild "${MPFR_VERSION}"
debug ../../${MPFR_VERSION}/configure --prefix="${MPFR_PREFIX}" --with-gmp="${GMP_PREFIX}" $MPFR_CYGWIN
debug make $MAKE_OPTIONS
debug $SUDO make install
popd

# MPC
#
wget -nc "ftp://ftp.gnu.org/gnu/mpc/${MPC_VERSION}.tar.gz"
untar "${MPC_VERSION}"
mkbuild "${MPC_VERSION}"
debug ../../${MPC_VERSION}/configure --prefix="${MPC_PREFIX}" --with-gmp="${GMP_PREFIX}" --with-mpfr="${MPFR_PREFIX}" $MPC_CYGWIN
debug make $MAKE_OPTIONS
debug $SUDO make install
popd

# ISL
#
wget -nc "ftp://gcc.gnu.org/pub/gcc/infrastructure/${ISL_VERSION}.tar.bz2"
untar "${ISL_VERSION}"
mkbuild "${ISL_VERSION}"
debug ../../${ISL_VERSION}/configure --prefix="${ISL_PREFIX}" --with-gmp-prefix="${GMP_PREFIX}" $ISL_CYGWIN
debug make $MAKE_OPTIONS
debug $SUDO make install
popd

#############################################################################

# https://gcc.gnu.org/ml/gcc/2014-07/msg00118.html

# GCC
#
wget -nc "https://ftp.gnu.org/gnu/gcc/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
untar "${GCC_VERSION}"

case "$OSTYPE" in
	darwin*)
		mkbuild "${GCC_VERSION}-native"
		debug ../../${GCC_VERSION}/configure\
				--prefix="${GCC_PREFIX}"\
				--enable-languages=c\
				--with-gmp="${GMP_PREFIX}"\
				--with-mpfr="${MPFR_PREFIX}"\
				--with-mpc="${MPC_PREFIX}"\
				--with-isl="${ISL_PREFIX}"
		debug make $MAKE_OPTIONS
		debug $SUDO make install
		popd
		;;
esac

#############################################################################

# BINUTILS
#
wget -nc "http://ftp.gnu.org/gnu/binutils/${BINUTILS_VERSION}.tar.bz2"
# wget -nc "ftp://sourceware.org/pub/binutils/snapshots/${BINUTILS_VERSION}.tar.bz2"
untar "${BINUTILS_VERSION}"
mkbuild "${BINUTILS_VERSION}-${TARGET}"
debug CPP="\"${GCC_PREFIX}/bin/cpp\""\
		CC="\"${GCC_PREFIX}/bin/gcc\""\
		CXX="\"${GCC_PREFIX}/bin/g++\""\
		../../${BINUTILS_VERSION}/configure\
		--prefix="${TARGET_BINUTILS_PREFIX}"\
		--target="${TARGET}"
debug make $MAKE_OPTIONS
debug $SUDO make install
popd

# rebuild GCC for TARGET platform
#
mkbuild "${GCC_VERSION}-${TARGET}"
debug CPP="\"${GCC_PREFIX}/bin/cpp\""\
		CC="\"${GCC_PREFIX}/bin/gcc\""\
		CXX="\"${GCC_PREFIX}/bin/g++\""\
		../../${GCC_VERSION}/configure\
		--prefix="${TARGET_GCC_PREFIX}/"\
		--target="${TARGET}"\
		$CONFIGURE_OPTIONS\
		--enable-languages=c\
		--with-newlib\
		--with-gmp="${GMP_PREFIX}"\
		--with-mpfr="${MPFR_PREFIX}"\
		--with-mpc="${MPC_PREFIX}"\
		--with-isl="${ISL_PREFIX}"
debug make $MAKE_OPTIONS all-gcc
debug $SUDO make install-gcc
popd

export PATH="${TARGET_GCC_PREFIX}/bin:${TARGET_BINUTILS_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${TARGET_GCC_PREFIX}/lib:${TARGET_BINUTILS_PREFIX}/lib:${LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="${TARGET_GCC_PREFIX}/lib:${TARGET_BINUTILS_PREFIX}/lib:${DYLD_LIBRARY_PATH}"

# NEWLIB
#
wget -nc "ftp://sourceware.org/pub/newlib/${NEWLIB_VERSION}.tar.gz"
untar "${NEWLIB_VERSION}"
mkbuild "${NEWLIB_VERSION}-${TARGET}"
debug CPP="\"${GCC_PREFIX}/bin/cpp\""\
		CC="\"${GCC_PREFIX}/bin/gcc\""\
		CXX="\"${GCC_PREFIX}/bin/g++\""\
		../../${NEWLIB_VERSION}/configure\
		--prefix="${TARGET_NEWLIB_PREFIX}/"\
		--target="${TARGET}"\
		$CONFIGURE_OPTIONS
debug make $MAKE_OPTIONS all
debug $SUDO make install
popd

# GCC
#
mkbuild "${GCC_VERSION}-${TARGET}"
debug make $MAKE_OPTIONS all
debug $SUDO make install
popd

#############################################################################

# GIT
#
case "$OSTYPE" in
	linux*)
		wget -O "git-${GIT_VERSION}.tar.gz" -nc "https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz"
		untar "git-${GIT_VERSION}"
		pushd "git-${GIT_VERSION}"
		debug make $MAKE_OPTIONS NO_TCLTK=YesPlease
		debug make install
		popd
		;;
esac

cat << EOF

--------------------------------------------
Add the following lines to your environment:

export PATH=\$PATH:\$HOME/bin
export PATH=\$PATH:$TARGET_PREFIX/bin
export PATH=\$PATH:$PWD/apache-ant/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$TARGET_PREFIX/lib
export DYLD_LIBRARY_PATH=\$DYLD_LIBRARY_PATH:$TARGET_PREFIX/lib

EOF
