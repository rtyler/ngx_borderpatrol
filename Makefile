# Debian package name & version
MAJOR_VER=0
MINOR_VER=1
PATCH_VER=0
PKG_NAME=borderpatrol
BUILD_VER=0${BUILD_NUMBER}-dev

# binaries
CC:=clang
LUAROCKS=luarocks

# nginx and lua modules
MODULE_PATH=${PWD}
MODULE_PKG_DIR=${MODULE_PATH}/pkg
CONTRIB_PATH=${MODULE_PATH}/contrib
NGINX_PATH=${CONTRIB_PATH}/nginx
NDK_PATH=${CONTRIB_PATH}/ngx_devel_kit
MEMC_NGINX_PATH=${CONTRIB_PATH}/memc-nginx-module
LUA_MODULE_PATH=${CONTRIB_PATH}/lua-nginx-module
ECHO_MODULE_PATH=${CONTRIB_PATH}/echo-nginx-module
STICKY_MODULE_PATH=${CONTRIB_PATH}/nginx-sticky-module
HEADERS_MORE_MODULE_PATH=${CONTRIB_PATH}/headers-more-nginx-module

NGINX_MODULES=--add-module=${NDK_PATH} \
							--add-module=${MEMC_NGINX_PATH} \
							--add-module=${LUA_MODULE_PATH} \
							--add-module=${STICKY_MODULE_PATH} \
							--add-module=${HEADERS_MORE_MODULE_PATH} \
							--add-module=${ECHO_MODULE_PATH} # only needed for

# build locations
BUILD_PATH=${MODULE_PATH}/build
DESTDIR=${PWD}/${PKG_NAME}

# packaging locations
CONF_DIR=/etc/${PKG_NAME}
SBIN_DIR=/usr/sbin
LOG_DIR=/var/log/${PKG_NAME}
SHARE_DIR=/usr/share/${PKG_NAME}

# test locations
TEST_DIR = ${MODULE_PATH}/t
TEST_RUN_DIR = ${TEST_DIR}/servroot

UNAME:=$(shell uname -s)

ifeq ($(UNAME), Darwin)
CFLAGS+="-I /usr/local/include -Wno-error"
LD_FLAGS+="-L /usr/local/lib -L /usr/lib -liconv"
endif

all: build

$(BUILD_PATH)/.install_rocks:
	@$(LUAROCKS) install luajson --to=$(BUILD_PATH)/usr
	@$(LUAROCKS) install luacrypto --to=$(BUILD_PATH)/usr
	@touch $(BUILD_PATH)/.install_rocks

build: submodules compile mkdirs $(BUILD_PATH)/.install_rocks
	@cp ${NGINX_PATH}/objs/nginx ${BUILD_PATH}${SBIN_DIR}/${PKG_NAME}
	@cp -rp ${PWD}/src/*.lua ${BUILD_PATH}${SHARE_DIR}
	@cp ${PWD}/src/robots.txt ${BUILD_PATH}${SHARE_DIR}
	@cp ${PWD}/src/config/nginx.conf.sample ${BUILD_PATH}${CONF_DIR}/sites-available/${PKG_NAME}.conf.sample
	@cp ${PWD}/src/ssl/server.crt ${BUILD_PATH}${CONF_DIR}/ssl/server.crt
	@cp ${PWD}/src/ssl/server.key ${BUILD_PATH}${CONF_DIR}/ssl/server.key

submodules:
	git submodule init
	git submodule update

mkdirs:
	@mkdir -p ${BUILD_PATH}${CONF_DIR}/conf.d
	@mkdir -p ${BUILD_PATH}${CONF_DIR}/sites-available
	@mkdir -p ${BUILD_PATH}${CONF_DIR}/sites-enabled
	@mkdir -p ${BUILD_PATH}${CONF_DIR}/ssl
	@mkdir -p ${BUILD_PATH}${SHARE_DIR}
	@mkdir -p ${BUILD_PATH}${CONF_DIR}
	@mkdir -p ${BUILD_PATH}${SBIN_DIR}

compile:
	@if [ ! -f ${NGINX_PATH}/Makefile ]; then (cd ${NGINX_PATH} && \
	./configure --prefix=/usr \
							--sbin-path=${SBIN_DIR}/borderpatrol \
							--conf-path=${CONF_DIR}/borderpatrol.conf \
							--pid-path=/var/run/borderpatrol.pid \
							--error-log-path=${LOG_DIR}/error.log \
							--http-log-path=${LOG_DIR}/access.log \
							${NGINX_MODULES} \
							--with-ld-opt=${LD_FLAGS} \
							--with-cc-opt=${CFLAGS} \
							--with-http_ssl_module); \
	fi;
	@(cd ${NGINX_PATH} && make -j2)

.PHONY : test

test: build
	@TEST_NGINX_BINARY=${PKG_NAME} PATH=${BUILD_PATH}${SBIN_DIR}:${PATH} prove -r ${TEST_DIR}/*.t

mocktest: build
	god -Dbc t/borderpatrol.god

make clean:
	rm -rf ${BUILD_PATH}
	rm -rf ${DESTDIR}
	rm -rf ngx_borderpatrol*
	rm -rf *.deb

distclean: clean
	(cd ${NGINX_PATH} && if [ -f Makefile ]; then make clean; fi;)

pkg: test

	# copy the build target dir to the package dir
	rm -rf ${DESTDIR}
	mv ${BUILD_PATH} ${DESTDIR}

	# Install configs under /etc/borderpatrol
	cp ${MODULE_PKG_DIR}/borderpatrol.conf ${DESTDIR}${CONF_DIR}/borderpatrol.conf
	chmod 0600 ${DESTDIR}${CONF_DIR}/borderpatrol.conf
	chmod 0600 ${DESTDIR}${CONF_DIR}/sites-available/*

	# Install package hooks
	cp ${MODULE_PKG_DIR}/after-install.sh ${DESTDIR}

	# Setup upstart config
	mkdir -p ${DESTDIR}/etc/init.d
	cp ${MODULE_PKG_DIR}/borderpatrol.init ${DESTDIR}/etc/init.d/borderpatrol
	chmod 755 ${DESTDIR}/etc/init.d/borderpatrol

	# Create extra directories
	mkdir -p ${DESTDIR}/var/log/borderpatrol
	mkdir -p ${DESTDIR}/var/borderpatrol
	mkdir -p ${DESTDIR}/var/cache/borderpatrol

	##########################################################################
	# create the borderpatrol package

	# install fpm if needed
	test -n "$(shell gem query --local fpm|grep fpm)" || gem install fpm

	cd ${DESTDIR} && fpm -s dir -t deb -n borderpatrol -v ${MAJOR_VER}.${MINOR_VER}.${PATCH_VER}-${BUILD_VER} -C ${DESTDIR} \
	  -p borderpatrol-VERSION_ARCH.deb \
	  --after-install after-install.sh \
	  -d libssl1.0.0 \
	  -d luarocks \
	  usr/ etc/ var/

	mv ${DESTDIR}/*.deb ${PWD}/
