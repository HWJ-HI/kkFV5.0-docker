# kkFileView 多阶段构建（在镜像内执行 Maven 打包）
# 网络不稳定时推荐使用 Dockerfile.prebuilt + 宿主机先 mvn package

ARG KKFILEVIEW_VERSION=5.0.0
ARG RUNTIME_BASE=eclipse-temurin:21-jre-jammy
ARG SKIP_BASE_SETUP=false

# ========== 1. Maven 编译阶段 ==========
FROM maven:3.9-eclipse-temurin-21 AS builder

ARG KKFILEVIEW_VERSION

WORKDIR /build

COPY pom.xml .
COPY server/pom.xml server/
# 系统依赖 jar，必须在 mvn 之前存在（不可被 go-offline 提前解析）
COPY server/lib/ server/lib/
COPY docker/maven/settings.xml /root/.m2/settings.xml

COPY server/src server/src
COPY server/src/main/assembly server/src/main/assembly
COPY server/src/main/bin server/src/main/bin
COPY server/src/main/config server/src/main/config
COPY server/src/main/log server/src/main/log
COPY server/src/main/resources server/src/main/resources

# 使用 BuildKit 缓存 Maven 本地仓库，加速重复构建
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn -B -s /root/.m2/settings.xml package -Dmaven.test.skip=true -pl server -am

# ========== 2. 运行时基础环境 ==========
FROM ${RUNTIME_BASE} AS base

ARG SKIP_BASE_SETUP

RUN if [ "${SKIP_BASE_SETUP}" != "true" ]; then \
      sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list && \
      sed -i 's|http://security.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list && \
      apt-get update && \
      export DEBIAN_FRONTEND=noninteractive && \
      apt-get install -y --no-install-recommends \
          tzdata locales xfonts-utils fontconfig libreoffice-nogui curl ca-certificates && \
      echo 'Asia/Shanghai' > /etc/timezone && \
      ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
      localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8 && \
      locale-gen zh_CN.UTF-8 && \
      apt-get install -y --no-install-recommends ttf-mscorefonts-installer && \
      apt-get install -y --no-install-recommends ttf-wqy-microhei ttf-wqy-zenhei xfonts-wqy && \
      apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

COPY docker/kkfileview-base/fonts/ /usr/share/fonts/chinese/

RUN if [ "${SKIP_BASE_SETUP}" != "true" ]; then \
      cd /usr/share/fonts/chinese && mkfontscale && mkfontdir && fc-cache -fv; \
    fi

ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

# ========== 3. 最终运行镜像 ==========
FROM base AS runtime

ARG KKFILEVIEW_VERSION

ENV KKFILEVIEW_VERSION=${KKFILEVIEW_VERSION} \
    KKFILEVIEW_BIN_FOLDER=/opt/kkFileView-${KKFILEVIEW_VERSION}/bin \
    KK_SERVER_PORT=8012

COPY --from=builder /build/server/target/kkFileView-*.tar.gz /tmp/kkFileView.tar.gz

RUN tar -xzf /tmp/kkFileView.tar.gz -C /opt/ && \
    rm /tmp/kkFileView.tar.gz && \
    mkdir -p /opt/kkFileView-${KKFILEVIEW_VERSION}/file \
             /opt/kkFileView-${KKFILEVIEW_VERSION}/log

WORKDIR /opt/kkFileView-${KKFILEVIEW_VERSION}

EXPOSE 8012

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${KK_SERVER_PORT}/actuator/health" || exit 1

ENTRYPOINT ["sh", "-c", "exec java -Dfile.encoding=UTF-8 -Dspring.config.location=/opt/kkFileView-${KKFILEVIEW_VERSION}/config/application.properties -jar /opt/kkFileView-${KKFILEVIEW_VERSION}/bin/kkFileView-${KKFILEVIEW_VERSION}.jar"]
