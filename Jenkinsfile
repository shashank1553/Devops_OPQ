pipeline {
    agent { label 'dev' }

    parameters {
        booleanParam(
            name: 'SONAR',
            defaultValue: false,
            description: 'Run Sonar scan'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'qa', 'uat', 'prod'],
            description: 'Deployment environment'
        )
        string(
            name: 'COMMAND',
            defaultValue: 'touch shashank',
            description: 'Build command to execute'
        )
    }

    stages {
        stage('Git checkout') {
            steps {
                echo 'This is checkout stage'
                // Add your Git checkout commands here
            }
        }
        stage('Build') {
            steps {
                echo 'This is Build stage'
                echo "Executing command: ${params.COMMAND}"
				dir('/home/ubuntu/jenkins/workspace/parameterized_pipeline/abc/') {
					sh "${params.COMMAND}"
				}
            }
        }
        stage('Sonar') {
            when {
                expression { return params.SONAR }
            }
            steps {
                echo 'This is Sonar scan stage'
                echo "Sonar environment: ${params.ENVIRONMENT}"
                // Add your Sonar scan commands here
                // For example:
                // sh "mvn sonar:sonar -Dsonar.projectKey=your_project_key -Dsonar.host.url=http://sonar-server -Dsonar.login=your_sonar_token"
            }
        }
        stage('Deploy') {
            steps {
                echo 'This is Deploy stage'
                echo "Deploying to environment: ${params.ENVIRONMENT}"
                // Add your deployment commands here
            }
        }
    }

    post {
        always {
            echo 'This will always run, regardless of success or failure'
        }
        success {
            echo 'This will run only if the pipeline succeeds'
        }
        failure {
            echo 'This will run only if the pipeline fails'
        }
    }
}
