# Prometheus

针对 [Prometheus](https://prometheus.io) 应用的 Docker 镜像，用于提供 Prometheus 服务。

详细信息可参照：[官方说明](https://prometheus.io/docs/introduction/overview/)

**版本信息**：

- 2.19、latest

**镜像信息**

* 镜像地址：registry.cn-shenzhen.aliyuncs.com/colovu/promethesu:2.19



## TL;DR

Docker 快速启动命令：

```shell
$ docker run -d registry.cn-shenzhen.aliyuncs.com/colovu/prometheus:2.19
```

Docker-Compose 快速启动命令：

```shell
$ curl -sSL https://raw.githubusercontent.com/colovu/docker-prometheus/master/docker-compose.yml > docker-compose.yml

$ docker-compose up -d
```



---



## 默认对外声明

### 端口

- 9090：Prometheus Web 端口

### 数据卷

镜像默认提供以下数据卷定义，默认数据分别存储在自动生成的应用名对应`prometheus`子目录中：

```shell
/var/log			# 日志输出
/srv/conf			# 配置文件
/srv/data			# 数据存储
```

如果需要持久化存储相应数据，需要**在宿主机建立本地目录**，并在使用镜像初始化容器时进行映射。宿主机相关的目录中如果不存在对应应用`Prometheus`的子目录或相应数据文件，则容器会在初始化时创建相应目录及文件。



## 容器配置

### 常规配置参数

Prometheus 的配置主要通过修改文件`prometheus.yml`进行配置。该容器使用，默认需要映射`/srv/conf`数据卷：

在宿主机创建用于映射数据卷的目录，如 `/tmp/conf`:

```shell
$ mkdir -p /tmp/conf
```

创建子目录，并将`prometheus.yml`文件放至该子目录中：

```shell
$ mkdir -p /tmp/conf/prometheus

$ cp ./prometheus.yml /tmp/conf/prometheus/
```

如有需要，可随时对该配置文件进行修改，并在修改后重新启动容器。



### 可选配置参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

#### `ENV_DEBUG`

默认值：**false**。设置是否输出容器调试信息。可设置为：1、true、yes



## 安全

### 容器安全

本容器默认使用应用对应的运行时用户及用户组运行应用，以加强容器的安全性。在使用非`root`用户运行容器时，相关的资源访问会受限；应用仅能操作镜像创建时指定的路径及数据。使用`Non-root`方式的容器，更适合在生产环境中使用。



## 注意事项

- 容器中启动参数不能配置为后台运行，如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



## 更新记录

- 2020.7.25：2.19、latest



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)
