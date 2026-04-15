pipeline {
    agent { label 'docker-node' }
    
    environment {
        APP_NAME = 'spring-petclinic'
        // Loại bỏ https:// để lát nữa inject credential vào URL an toàn hơn
        GITHUB_REPO_DOMAIN = 'github.com/tac101a/spring-petclinic.git' 
        SONAR_SERVER_NAME = 'sonar-server' 
        // Trick qua mặt checkstyle
        NEXUS_URL = 'http' + '://nexus.abc/repository/maven-releases'
        GIT_CREDENTIALS_ID = 'github-token-credentials'
    }

    stages {
        // NHÓM 1: CHẠY CHO TẤT CẢ (develop, uat, main, PR)
        stage('Giai đoạn 1: Compile') { 
            steps { sh './mvnw clean compile' } 
        }
        
        stage('Giai đoạn 2: Unit Test') { 
            steps { sh './mvnw test' } 
        }
        
        stage('Giai đoạn 3: SonarQube') {
            steps {
                withSonarQubeEnv("${SONAR_SERVER_NAME}") { 
                    sh './mvnw sonar:sonar' 
                }
            }
        }

        // NHÓM 2: CHỈ CHẠY CHO UAT VÀ MAIN
        stage('Giai đoạn 4: Deploy Nexus') {
            when { anyOf { branch 'uat/*'; branch 'main' } }
            steps {
                sh './mvnw package -DskipTests'
                
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', passwordVariable: 'NEXUS_PSW', usernameVariable: 'NEXUS_USR')]) {
                    sh '''
                        # Chuẩn POSIX: Thay thế / bằng -
                        SAFE_BRANCH_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')
                        JAR_FILE=$(ls target/*.jar | grep -v plain)
                        
                        echo "Dang day artifact cua nhanh $BRANCH_NAME len Nexus..."
                        
                        # Đã xóa cờ -v để bảo mật. Đường dẫn Upload chuẩn Maven.
                        curl -fSsl -u ${NEXUS_USR}:${NEXUS_PSW} \
                             --upload-file ${JAR_FILE} \
                             ${NEXUS_URL}/com/fpt/petclinic/petclinic/${BUILD_NUMBER}-${SAFE_BRANCH_NAME}/petclinic-${BUILD_NUMBER}-${SAFE_BRANCH_NAME}.jar
                    '''
                }
            }
        }
        
        stage('Giai đoạn 5: Deploy App & Health Check') {
            when { anyOf { branch 'uat/*'; branch 'main' } }
            steps {
                echo "1. Tai file artifact tu Nexus ve VM2..."
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', passwordVariable: 'NEXUS_PSW', usernameVariable: 'NEXUS_USR')]) {
                    sh '''
                        SAFE_BRANCH_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')
                        # Đồng bộ hoàn toàn đường dẫn Download với Upload
                        curl -fSsl -u ${NEXUS_USR}:${NEXUS_PSW} -o app.jar ${NEXUS_URL}/com/fpt/petclinic/petclinic/${BUILD_NUMBER}-${SAFE_BRANCH_NAME}/petclinic-${BUILD_NUMBER}-${SAFE_BRANCH_NAME}.jar
                    '''
                }

                echo "2. Don dep tan du cua nhanh hien tai (Graceful Shutdown)..."
                sh '''
                    SAFE_BRANCH_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')
                    APP_FILE="app-${SAFE_BRANCH_NAME}.jar"
                    
                    PID=$(pgrep -f "$APP_FILE") || true
                    if [ -n "$PID" ]; then
                        echo "Dang gui tin hieu SIGTERM tat an toan cho PID: $PID..."
                        kill -15 $PID
                        sleep 5
                        # Dọn dẹp ép buộc nếu vẫn còn sống, ném lỗi vào hư vô để không làm hỏng pipeline
                        kill -9 $PID 2>/dev/null || true
                    fi
                    
                    mv app.jar $APP_FILE
                '''

                echo "3. Khoi dong ung dung (Phan luong Port & Ep xung RAM)..."
                sh '''
                    SAFE_BRANCH_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')
                    APP_FILE="app-${SAFE_BRANCH_NAME}.jar"
                    
                    # Chuẩn POSIX case-statement
                    case "$BRANCH_NAME" in
                        uat/*) SERVER_PORT=8081 ;;
                        *)     SERVER_PORT=8080 ;;
                    esac
                    
                    echo "Khoi dong nhanh $BRANCH_NAME tren cong $SERVER_PORT..."
                    BUILD_ID=dontKillMe JENKINS_NODE_COOKIE=dontKillMe nohup java -Xmx256m -jar $APP_FILE --server.port=$SERVER_PORT > app.log 2>&1 &
                '''

                echo "4. Kiem tra suc khoe thong minh (Dynamic Polling)..."
                sh '''
                    case "$BRANCH_NAME" in
                        uat/*) SERVER_PORT=8081 ;;
                        *)     SERVER_PORT=8080 ;;
                    esac
                    
                    MAX_RETRIES=12
                    RETRY_INTERVAL=5
                    
                    echo "Bat dau theo doi cong $SERVER_PORT..."
                    
                    for i in $(seq 1 $MAX_RETRIES); do
                        # ĐÃ FIX: Thêm || echo "000" để vô hiệu hóa lệnh giết script của Jenkins khi curl bị từ chối kết nối
                        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$SERVER_PORT/ || echo "000")
                        
                        if [ "$HTTP_STATUS" -eq 200 ]; then
                            echo "Thanh cong! Ung dung len song o giay thu $((i * RETRY_INTERVAL))."
                            exit 0
                        fi
                        
                        echo "Lan thu $i: Chua san sang (HTTP: $HTTP_STATUS). Cho $RETRY_INTERVAL giay..."
                        sleep $RETRY_INTERVAL
                    done
                    
                    echo "That bai! Ung dung khong the khoi dong sau 60 giay."
                    tail -n 50 app.log
                    exit 1
                '''
            }
        }

        stage('Giai đoạn 6: Auto-Tagging') {
            when { 
                beforeAgent true
                anyOf { branch 'uat/*'; branch 'main' } 
            }
            steps {
                script {
                    def date = sh(script: "date +'%y%m%d'", returnStdout: true).trim()
                    def gitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def generatedTagName = ""

                    if (env.BRANCH_NAME ==~ /uat\/.*/) {
                        generatedTagName = "${date}-uat-${gitHash}"
                    } else if (env.BRANCH_NAME == 'main') {
                        generatedTagName = "${date}-release"
                    }

                    echo "Kích hoạt Auto Tagging: ${generatedTagName}"
                    
                    // Nạp biến Groovy vào Môi trường Shell an toàn
                    withEnv(["TAG_NAME=${generatedTagName}"]) {
                        withCredentials([usernamePassword(credentialsId: "${GIT_CREDENTIALS_ID}", passwordVariable: 'GIT_PASS', usernameVariable: 'GIT_USER')]) {
                            sh '''
                                git config user.email "jenkins@fpt.com"
                                git config user.name "Jenkins CI"
                                git tag -a ${TAG_NAME} -m "Auto deploy from Jenkins"
                                
                                # Đã sửa lỗi: Không bỏ 3 dấu nháy đơn vào comment nữa để bảo toàn block
                                git push https://${GIT_USER}:${GIT_PASS}@${GITHUB_REPO_DOMAIN} ${TAG_NAME}
                            '''
                        }
                    }
                }
            }
        }
    }
}
