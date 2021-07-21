# Ver: 1.8 by Endial Fang (endial@126.com)
#

# 可变参数 ========================================================================

# 设置当前应用名称及版本
ARG app_name=prometheus
ARG app_version=2.28.1

# 设置默认仓库地址，默认为 阿里云 仓库
ARG registry_url="registry.cn-shenzhen.aliyuncs.com"

# 设置 apt-get 源：default / tencent / ustc / aliyun / huawei
ARG apt_source=aliyun

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""


# 0. 预处理 ======================================================================
FROM ${registry_url}/colovu/dbuilder as builder

# 声明需要使用的全局可变参数
ARG app_name
ARG app_version
ARG registry_url
ARG apt_source
ARG local_url


ENV APP_NAME=${app_name} \
	APP_VERSION=${app_version}

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source};

# 安装依赖的软件包及库(Optional)
#RUN install_pkg xz-utils

# 设置工作目录
WORKDIR /tmp

# 下载并解压软件包
RUN set -eux; \
	dpkgOsArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	dpkgOsName="$(uname | tr [:'upper':] [:'lower':])"; \
	appName="${APP_NAME}-${APP_VERSION}.${dpkgOsName}-${dpkgOsArch}.tar.gz"; \
	sha256="91dd91e13f30fe520e01175ca1027dd09a458d4421a584ba557ba88b38803f27"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/prometheus; \
	appUrls="${localURL:-} \
		https://github.com/prometheus/prometheus/releases/download/v${APP_VERSION} \
		"; \
	download_pkg unpack ${appName} "${appUrls}" -s "${sha256}";



# 1. 生成镜像 =====================================================================
FROM ${registry_url}/colovu/debian:buster

# 声明需要使用的全局可变参数
ARG app_name
ARG app_version
ARG registry_url
ARG apt_source
ARG local_url


# 镜像所包含应用的基础信息，定义环境变量，供后续脚本使用
ENV APP_NAME=${app_name} \
	APP_USER=${app_name} \
	APP_EXEC=${app_name} \
	APP_VERSION=${app_version}

ENV	APP_HOME_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME}

ENV PATH="${APP_HOME_DIR}:${PATH}" \
	LD_LIBRARY_PATH="${APP_HOME_DIR}/lib"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME}(v${APP_VERSION})." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

# 从预处理过程中拷贝软件包(Optional)，可以使用阶段编号或阶段命名定义来源
COPY --from=builder /tmp/prometheus-${APP_VERSION}.linux-amd64 /usr/local/prometheus
COPY --from=builder /tmp/prometheus-${APP_VERSION}.linux-amd64/prometheus.yml /etc/prometheus

# 拷贝应用使用的客制化脚本，并创建对应的用户及数据存储目录
COPY customer /
RUN set -eux; \
#	create_user; \
	prepare_env;

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source}
#RUN install_pkg bash


# 执行预处理脚本，并验证安装的软件包
RUN set -eux; \
	override_file="/usr/local/overrides/overrides-${APP_VERSION}.sh"; \
	[ -e "${override_file}" ] && /bin/bash "${override_file}"; \
	${APP_EXEC} --version ;

# 默认提供的数据卷
VOLUME ["/srv/conf", "/srv/data", "/srv/cert", "/var/log"]

# 默认non-root用户启动，必须保证端口在1024之上
EXPOSE 9090

# 关闭基础镜像的健康检查
#HEALTHCHECK NONE

# 应用健康状态检查
#HEALTHCHECK --interval=30s --timeout=30s --retries=3 \
#	CMD curl -fs http://localhost:8080/ || exit 1
#HEALTHCHECK --interval=10s --timeout=10s --retries=3 \
#	CMD netstat -ltun | grep 9090

# 使用 non-root 用户运行后续的命令
USER 1001

# 设置工作目录
WORKDIR /srv/data/prometheus

# 容器初始化命令
ENTRYPOINT ["/usr/local/bin/entry.sh"]

# 应用程序的启动命令，必须使用非守护进程方式运行
CMD ["/usr/local/bin/run.sh"]

