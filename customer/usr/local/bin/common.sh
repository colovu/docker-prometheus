#!/bin/bash
# Ver: 1.1 by Endial Fang (endial@126.com)
# 
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/libcommon.sh       # 通用函数库

. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/liblog.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libservice.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 检测用户参数信息是否满足条件; 针对部分权限过于开放情况，打印提示信息
prometheus_verify_minimum_env() {
    local error_code=0

    LOG_D "Validating settings in PROMETHEUS_* env vars..."

    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    # TODO: 其他参数检测

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

# 更改默认监听地址为 "*" 或 "0.0.0.0"，以对容器外提供服务；默认配置文件应当为仅监听 localhost(127.0.0.1)
prometheus_enable_remote_connections() {
    LOG_D "Modify default config to enable all IP access"
	
}

# 清理初始化应用时生成的临时文件
prometheus_clean_tmp_file() {
    LOG_D "Clean ${APP_NAME} tmp files for init..."

}

# 在重新启动容器时，删除标志文件及必须删除的临时文件 (容器重新启动)
prometheus_clean_from_restart() {
    LOG_D "Clean ${APP_NAME} tmp files for restart..."
    local -r -a files=(

    )

    for file in ${files[@]}; do
        if [[ -f "$file" ]]; then
            LOG_I "Cleaning stale $file file"
            rm "$file"
        fi
    done
}

# 应用默认初始化操作
# 执行完毕后，生成文件 ${APP_CONF_DIR}/.prometheus_init_flag 及 ${APP_DATA_DIR}/.data_init_flag 文件
prometheus_default_init() {
	prometheus_clean_from_restart
    LOG_D "Check init status of ${APP_NAME}..."

    # 检测配置文件是否存在
    if [[ ! -f "${APP_CONF_DIR}/.app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        
        # TODO: 生成配置文件，并按照容器运行参数进行相应修改

        touch ${APP_CONF_DIR}/.app_init_flag
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_CONF_DIR}/.app_init_flag
    else
        LOG_I "User injected custom configuration detected!"
    fi

    if [[ ! -f "${APP_DATA_DIR}/.data_init_flag" ]]; then
        LOG_I "Deploying ${APP_NAME} from scratch..."

        # TODO: 根据需要生成相应初始化数据

        touch ${APP_DATA_DIR}/.data_init_flag
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.data_init_flag
    else
        LOG_I "Deploying ${APP_NAME} with persisted data..."
    fi
}

# 用户自定义的前置初始化操作，依次执行目录 preinitdb.d 中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_preinit_flag
prometheus_custom_preinit() {
    LOG_D "Check custom pre-init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 preinitdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/preinitdb.d" ]; then
        # 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
        if [[ -n $(find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_preinit_flag" ]]; then
            LOG_I "Process custom pre-init scripts from /srv/conf/${APP_NAME}/preinitdb.d..."

            # 检索所有可执行脚本，排序后执行
            find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)" | sort | process_init_files

            touch ${APP_DATA_DIR}/.custom_preinit_flag
            echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.custom_preinit_flag
            LOG_I "Custom preinit for ${APP_NAME} complete."
        else
            LOG_I "Custom preinit for ${APP_NAME} already done before, skipping initialization."
        fi
    fi

    # 检测依赖的服务是否就绪
    #for i in ${SERVICE_PRECONDITION[@]}; do
    #    prometheus_wait_service "${i}"
    #done
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_init_flag
prometheus_custom_init() {
    LOG_D "Check custom init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 initdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
    	if [[ -n $(find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_init_flag" ]]; then
            LOG_I "Process custom init scripts from /srv/conf/${APP_NAME}/initdb.d..."

            # 检索所有可执行脚本，排序后执行
    		find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort | while read -r f; do
                case "$f" in
                    *.sh)
                        if [[ -x "$f" ]]; then
                            LOG_D "Executing $f"; "$f"
                        else
                            LOG_D "Sourcing $f"; . "$f"
                        fi
                        ;;
                    *)        LOG_D "Ignoring $f" ;;
                esac
            done

            touch ${APP_DATA_DIR}/.custom_init_flag
    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.custom_init_flag
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi

    # 删除第一次运行生成的临时文件
    prometheus_clean_tmp_file

	# 绑定所有 IP ，启用远程访问
    prometheus_enable_remote_connections
}

