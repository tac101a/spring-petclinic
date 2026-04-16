# ==========================================
# STAGE 1: BUILDER (Khối xây dựng)
# ==========================================
# Sử dụng base image có sẵn Maven và JDK 17
FROM eclipse-temurin:17-jdk-jammy AS builder

# Thiết lập thư mục làm việc bên trong container
WORKDIR /app

# Copy file cấu hình maven trước để tận dụng Docker Cache
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Tải các thư viện dependency với chế độ Batch mode (-B) để tránh lỗi I/O
RUN ./mvnw dependency:go-offline -B

# Copy toàn bộ mã nguồn vào
COPY src ./src

# Tiến hành đóng gói ứng dụng (Bỏ test và bật Batch mode)
RUN ./mvnw package -DskipTests -B

# ==========================================
# STAGE 2: RUNTIME (Khối thực thi)
# ==========================================
# Chỉ sử dụng JRE (Môi trường chạy) siêu nhẹ, không cần Maven nữa
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Tạo một user không có quyền root để chạy ứng dụng (Bảo mật tối thượng)
RUN addgroup --system spring && adduser --system --ingroup spring springuser
USER springuser

# Ép xung RAM cho Java bên trong Container
ENV JAVA_OPTS="-Xmx256m -Xms256m"

# Chỉ copy đúng duy nhất cái file .jar từ STAGE 1 sang STAGE 2
COPY --from=builder /app/target/*.jar app.jar

# Khai báo cổng mà ứng dụng sẽ lắng nghe (Petclinic mặc định chạy 8080)
EXPOSE 8080

# Lệnh khởi chạy ứng dụng khi Container nổ máy
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
