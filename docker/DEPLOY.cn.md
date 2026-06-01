# kkFileView Docker 部署说明

## 方式一：宿主机打包 + Docker 运行（推荐，最稳定）

适用于 Docker 内访问 Maven Central / Aspose 仓库不稳定的环境。

```powershell
# 1. 在项目根目录打包（需本机已安装 JDK 21 + Maven）
mvn -B package -Dmaven.test.skip=true -pl server -am

# 2. 构建并启动
docker compose -f docker-compose.prebuilt.yml up -d --build
```

访问：http://localhost:8012/

## 方式二：Docker 内完整构建（一条命令）

需要 Docker 能稳定访问外网（含 `repository.aspose.com`）。

```powershell
# 建议启用 BuildKit
$env:DOCKER_BUILDKIT=1
docker compose up -d --build
```

首次构建约 10–20 分钟（下载依赖 + LibreOffice）。

## 常见问题

### `DependencyResolutionException` / 连接 `repo.maven.apache.org` 超时

- 优先使用 **方式一（prebuilt）**
- 或在 `docker/maven/settings.xml` 中已配置阿里云镜像，确认构建时使用了该文件

3. **修改 `application.properties` 后不生效**

   镜像内配置来自 `mvn package` 生成的 tar.gz，**不会自动同步源码修改**。

   任选其一：
   - 已配置 volume 挂载时：`docker compose restart` 即可
   - 或重新打包：`mvn package` → `docker compose up -d --build`
   - 或设置环境变量：`KK_TRUST_HOST=*`（见 docker-compose.yml）

   验证容器内实际配置：
   ```powershell
   docker exec kkfileview grep trust.host /opt/kkFileView-5.0.0/config/application.properties
   ```

从官方仓库恢复：

```powershell
git checkout server/lib
```

或从 [kkFileView/server/lib](https://github.com/kekingcn/kkFileView/tree/master/server/lib) 下载 `jai_core-1.1.3.jar` 与 `jai_codec-1.1.3.jar`。

### 镜像缓存异常

```powershell
docker builder prune -af
docker compose build --no-cache
```

## 环境变量（可选）

在 `docker-compose.yml` 的 `environment` 中可设置，例如：

- `KK_BASE_URL`：对外访问地址
- `KK_FILE_DIR`：文件存储路径
- `KK_CACHE_TYPE=redis` + `KK_SPRING_REDISSON_ADDRESS`：使用 Redis 缓存
