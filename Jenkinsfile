pipeline {
    agent { label 'docker-node' }
    
    environment {
        APP_NAME = 'spring-petclinic'
        // Repo cá nhân để có quyền Push Tag
        GITHUB_REPO = 'https://github.com/tac101a/spring-petclinic.git' 
        SONAR_SERVER_NAME = 'sonar-server' 
        NEXUS_URL = 'http://nexus.abc/repository/maven-releases'
        GIT_CREDENTIALS_ID = 'github-token-credentials'
    }

    stages {
        // NHÓM 1: CHẠY CHO TẤT CẢ (develop, uat, main, PR)
        stage('Giai đoạn 1: Compile') { 
            steps { 
                sh './mvnw clean compile' 
            } 
        }
        
        stage('Giai đoạn 2: Unit Test') { 
            steps { 
                sh './mvnw test' 
            } 
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
                        JAR_FILE=$(ls target/*.jar | grep -v plain)
                        curl -v -f -u ${NEXUS_USR}:${NEXUS_PSW} --upload-file ${JAR_FILE} ${NEXUS_URL}/com/fpt/petclinic/${BUILD_NUMBER}/petclinic-${BUILD_NUMBER}.jar
                    '''
                } // Đóng withCredentials
            } // Đóng steps
        } // ĐÓNG STAGE 4 (ĐÂY CHÍNH LÀ DẤU NGOẶC BẠN BỊ THIẾU)

        stage('Giai đoạn 5: Deploy App & Health Check') {
            when { anyOf { branch 'uat/*'; branch 'main' } }
            steps {
                echo "1. Tai file artifact tu Nexus ve VM2..."
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', passwordVariable: 'NEXUS_PSW', usernameVariable: 'NEXUS_USR')]) {
                    sh '''
                        curl -f -u ${NEXUS_USR}:${NEXUS_PSW} -o app.jar ${NEXUS_URL}/com/fpt/petclinic/${BUILD_NUMBER}/petclinic-${BUILD_NUMBER}.jar
                    '''
                }

                echo "2. Don dep tien trinh cu (Graceful Shutdown)..."
                sh '''
                    PID=$(pgrep -f "app.jar") || true
                    if [ ! -z "$PID" ]; then
                        echo "Dang tat tien trinh cu: $PID"
                        kill -9 $PID
                        sleep 3
                    fi
                '''

                echo "3. Khoi dong ung dung moi (Bat tu truoc ProcessTreeKiller)..."
                sh '''
                    # ĐÃ FIX: Bổ sung BUILD_ID=dontKillMe
                    BUILD_ID=dontKillMe JENKINS_NODE_COOKIE=dontKillMe nohup java -jar app.jar > app.log 2>&1 &
                '''

                echo "4. Kiem tra suc khoe thong minh (Dynamic Polling)..."
                sh '''
                    # ĐÃ FIX: Sử dụng vòng lặp thay vì sleep 40 cứng nhắc
                    MAX_RETRIES=12
                    RETRY_INTERVAL=5
                    
                    echo "Bat dau theo doi trang thai khoi dong..."
                    
                    for i in $(seq 1 $MAX_RETRIES); do
                        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
                        
                        if [ "$HTTP_STATUS" -eq 200 ]; then
                            echo "Thanh cong! Ung dung len song o giay thu $((i * RETRY_INTERVAL))."
                            exit 0
                        fi
                        
                        echo "Lan thu $i: Chua san sang (HTTP: $HTTP_STATUS). Cho $RETRY_INTERVAL giay..."
                        sleep $RETRY_INTERVAL
                    done
                    
                    echo "That bai! Ung dung khong the khoi dong."
                    cat app.log
                    exit 1
                '''
            }
        }

        // NHÓM 3: TỰ ĐỘNG ĐÁNH TAG (CHỈ CHO UAT VÀ MAIN)
        stage('Giai đoạn 6: Auto-Tagging') {
            when { 
                beforeAgent true
                anyOf { branch 'uat/*'; branch 'main' } 
            }
            steps {
                script {
                    def date = sh(script: "date +'%y%m%d'", returnStdout: true).trim()
                    def gitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def tagName = ""

                    if (env.BRANCH_NAME ==~ /uat\/.*/) {
                        tagName = "${date}-uat-${gitHash}"
                    } else if (env.BRANCH_NAME == 'main') {
                        tagName = "${date}-release"
                    }

                    echo "Kích hoạt Tagging: ${tagName}"
                    
                    withCredentials([usernamePassword(credentialsId: "${GIT_CREDENTIALS_ID}", passwordVariable: 'GIT_PASS', usernameVariable: 'GIT_USER')]) {
                        sh """
                            git config user.email "jenkins@fpt.com"
                            git config user.name "Jenkins CI"
                            git tag -a ${tagName} -m "Auto deploy from Jenkins"
                            git push https://${GIT_USER}:${GIT_PASS}@github.com/tac101a/spring-petclinic.git ${tagName}
                        """
                    }
                }
            }
        }
    }
}
