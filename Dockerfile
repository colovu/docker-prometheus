# Ver: 1.0 by Endial Fang (endial@126.com)
#
# 指定原始系统镜像，常用镜像为 colovu/ubuntu:18.04、colovu/debian:10-buster、colovu/alpine:3.11、colovu/openjdk:8u252-jre
FROM colovu/ubuntu:18.04

# 外部指定应用版本信息，如 "--build-arg app_ver=6.0.0"
ARG app_ver=2.19.2

# 编译镜像时指定本地服务器地址，如 "--build-arg local_url=http://172.29.14.108/dist-files/"
ARG local_url=""

# 定义应用基础常量信息，该常量在容器内可使用
ENV APP_NAME=prometheus \
	APP_EXEC=prometheus \
	APP_USER=prometheus \
	APP_GROUP=prometheus \
	APP_VERSION=${app_ver}

# 定义应用基础目录信息，该常量在容器内可使用
ENV	APP_BASE_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME} \
	APP_WWW_DIR=/srv/www

# 设置应用需要的特定环境变量
ENV \
	PATH="${APP_BASE_DIR}:${PATH}"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME} ${APP_VERSION}." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

# 拷贝默认 Shell 脚本至容器相关目录中
COPY prebuilds /

# 镜像内应用安装脚本
# 以下脚本可按照不同需求拆分为多个段，但需要注意各个段在结束前需要清空缓存
# set -eux: 设置 shell 执行参数，分别为 -e(命令执行错误则退出脚本) -u(变量未定义则报错) -x(打印实际待执行的命令行)
RUN set -eux; \
	\
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 设置容器入口脚本的可执行权限
	chmod +x /usr/local/bin/entrypoint.sh; \
	\
# 为应用创建对应的组、用户、相关目录
	APP_DIRS="${APP_DEF_DIR:-} ${APP_CONF_DIR:-} ${APP_DATA_DIR:-} ${APP_CACHE_DIR:-} ${APP_RUN_DIR:-} ${APP_LOG_DIR:-} ${APP_CERT_DIR:-} ${APP_WWW_DIR:-} ${APP_DATA_LOG_DIR:-} ${APP_BASE_DIR:-${APP_DATA_DIR}}"; \
	mkdir -p ${APP_DIRS}; \
	groupadd -r -g 998 ${APP_GROUP}; \
	useradd -r -g ${APP_GROUP} -u 999 -s /sbin/nologin -d ${APP_DATA_DIR} ${APP_USER}; \
	\
# 应用软件包及依赖项。相关软件包在镜像创建完成时，不会被清理
	appDeps=" \
		locales \
		tzdata \
	"; \
	\
	\
	\
# 安装临时使用的软件包及依赖项。相关软件包在镜像创建完后时，会被清理
	fetchDeps=" \
		wget \
		ca-certificates \
		\
		xz-utils \
	"; \
	savedAptMark="$(apt-mark showmanual) ${appDeps}"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
	\
	\
# 下载需要的软件包资源。可使用 不校验、签名校验、SHA256 校验 三种方式
	DIST_NAME="${APP_NAME}-${APP_VERSION}.linux-amd64.tar.gz"; \
	DIST_SHA256="68382959f73354b30479f9cc3e779cf80fd2e93010331652700dcc71f6b05586"; \
	DIST_URLS=" \
		${local_url} \
		https://github.com/prometheus/prometheus/releases/download/v${APP_VERSION}/ \
		"; \
	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}" "${DIST_URLS}"; \
#	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}" "${DIST_URLS}" --checksum "${DIST_SHA256}"; \
	\
	\
	\
# 二进制解压安装，并将原始配置文件拷贝至 ${APP_DEF_DIR} 中
	tar --extract --file "${DIST_NAME}" --directory "${APP_BASE_DIR}" --strip-components 1; \
	cp -rf ${APP_BASE_DIR}/prometheus.yml "${APP_DEF_DIR}/"; \
	rm -rf "${DIST_NAME}"; \
	\
	\
	\
# 增加软件包特有源，并使用系统包管理方式安装软件
	apt-get install -y --no-install-recommends ${appDeps}; \
	\
	\
	\
# 为中国区使用重新配置 TimeZone 信息。需要安装 tzdata 软件包
	ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
	dpkg-reconfigure -f noninteractive tzdata; \
	\
# 安装 UTF-8 编码。需要安装 locales 软件包
	localedef -c -i en_US -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; \
	echo 'en_GB.UTF-8 UTF-8\nen_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen; \
	update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_MESSAGES=POSIX && dpkg-reconfigure locales; \
	\
# 检测是否存在对应版本的 overrides 脚本文件；如果存在，执行
	{ [ ! -e "/usr/local/overrides/overrides-${APP_VERSION}.sh" ] || /bin/bash "/usr/local/overrides/overrides-${APP_VERSION}.sh"; }; \
	\
# 设置应用关联目录的权限信息，设置为'777'是为了保证后续使用`--user`或`gosu`时，可以更改目录对应的用户属性信息；运行时会被更改为'700'或'755'
	chown -Rf ${APP_USER}:${APP_GROUP} ${APP_DIRS}; \
	chmod 777 ${APP_DIRS}; \
	\
# 查找新安装的应用及应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
	apt-mark auto '.*' > /dev/null; \
	{ [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; }; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual; \
	\
# 删除安装的临时依赖软件包，清理缓存
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt-get autoclean -y; \
	rm -rf /var/lib/apt/lists/*; \
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	gosu ${APP_USER} ${APP_EXEC} --version ;

VOLUME ["/srv/conf", "/srv/data", "/var/log", "/var/run"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 9090

# 容器初始化命令，默认存放在：/usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行。如果使用变量，则该变量必须在运行环境中存在（ENV可以获取）
CMD ["${APP_EXEC}", "--config.file=${APP_CONF_DIR}/prometheus.yml", "--storage.tsdb.path=${APP_DATA_DIR}", "--web.console.libraries=${APP_BASE_DIR}/console_libraries", "--web.console.templates=${APP_BASE_DIR}/consoles"]
