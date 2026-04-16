@Library('my-shared-lib') _

pipeline {
    agent { label 'docker-node' }
    
    environment {
        APP_NAME = 'spring-petclinic'
        GITHUB_REPO_DOMAIN = 'github.com/tac101a/spring-petclinic.git'
        SONAR_SERVER_NAME = 'sonar-server'
        NEXUS_URL = 'http' + '://nexus.abc/repository/maven-releases'
        NEXUS_DOCKER_URL = 'docker.abc:80'
        DB_URL = 'jdbc:postgresql://10.0.0.5:5432/petclinic'
        DB_CREDENTIALS_ID = 'postgres-credentials'
        GIT_CREDENTIALS_ID = 'github-token-credentials'
        NEXUS_CREDENTIALS_ID = 'nexus-credentials'
    }

    stages {
        // GROUP 1: RUN FOR ALL (develop, uat, main, PR)
        stage('Giai doan 1: Compile') {
            steps {
                mavenExecute('clean compile')
            }
        }
        
        stage('Giai doan 2: Unit Test') {
            steps {
                mavenExecute('test')
            }
        }
        
        stage('Giai doan 3: SonarQube') {
            steps {
                sonarScan(env.SONAR_SERVER_NAME)
            }
        }

        // GROUP 2: RUN FOR ALL 3 ENVIRONMENTS (DEV, UAT, MAIN)
        stage('Giai doan 4: Deploy Nexus') {
            when {
                anyOf {
                    branch 'develop/*'
                    branch 'uat/*'
                    branch 'main'
                }
            }
            steps {
                mavenExecute('package -DskipTests')
                uploadToNexus(
                    branch: env.BRANCH_NAME,
                    buildNum: env.BUILD_NUMBER,
                    nexusUrl: env.NEXUS_URL,
                    credId: env.NEXUS_CREDENTIALS_ID
                )
            }
        }

        stage('Giai doan 4.5: Build & Push Docker') {
            when {
                anyOf {
                    branch 'develop/*'
                    branch 'uat/*'
                    branch 'main'
                }
            }
            steps {
                buildAndPushDocker(
                    appName: env.APP_NAME,
                    branch: env.BRANCH_NAME,
                    buildNum: env.BUILD_NUMBER,
                    nexusDockerUrl: env.NEXUS_DOCKER_URL,
                    credId: env.NEXUS_CREDENTIALS_ID
                )
            }
        }
        
        stage('Giai doan 5: Deploy App & Health Check') {
            when {
                anyOf {
                    branch 'develop/*'
                    branch 'uat/*'
                    branch 'main'
                }
            }
            steps {
                deployDockerApp(
                    appName: env.APP_NAME,
                    branch: env.BRANCH_NAME,
                    buildNum: env.BUILD_NUMBER,
                    nexusDockerUrl: env.NEXUS_DOCKER_URL,
                    dbUrl: env.DB_URL,
                    dbCredId: env.DB_CREDENTIALS_ID,
                    credId: env.NEXUS_CREDENTIALS_ID
                )
            }
        }

        // GROUP 3: RUN ONLY FOR UAT AND MAIN
        stage('Giai doan 6: Auto-Tagging') {
            when { 
                beforeAgent true
                anyOf {
                    branch 'uat/*'
                    branch 'main'
                }
            }
            steps {
                createGitTag(
                    branch: env.BRANCH_NAME,
                    buildNum: env.BUILD_NUMBER,
                    gitRepoDomain: env.GITHUB_REPO_DOMAIN,
                    credId: env.GIT_CREDENTIALS_ID
                )
            }
        }
    }
    post {
        success {
            notifySlack(
                status: 'SUCCESS',
                appName: env.APP_NAME,
                branch: env.BRANCH_NAME,
                buildNum: env.BUILD_NUMBER,
                buildUrl: env.BUILD_URL
            )
        }
        failure {
            notifySlack(
                status: 'FAILURE',
                appName: env.APP_NAME,
                branch: env.BRANCH_NAME,
                buildNum: env.BUILD_NUMBER,
                buildUrl: "${env.BUILD_URL}console"
            )
        }
    }
}
