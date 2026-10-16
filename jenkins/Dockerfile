FROM jenkins/jenkins:lts-jdk17

USER root
# Docker CLI only (no daemon): pipelines talk to the host Docker through the mounted socket.
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
COPY casc/jenkins.yaml /usr/share/jenkins/casc/jenkins.yaml

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Skip the setup wizard: everything is configured by Configuration as Code.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/usr/share/jenkins/casc/jenkins.yaml
