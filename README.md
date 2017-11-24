# JenkinsPipeline
This is a pipeline for build a jobs on command line.

Before you start, you need edit `var` on jenkins script for include the URL of your jenkins server, just change line below:

```bash
export JENKINS_SERVER_URL="YOUR_SERVER_URL_HERE"
```

# Authentication
By default, this script authenticates with SSH key pair.

## SSH key pair

### Locating an existing SSH key pair
Before generating a new SSH key check if your system already has one
at the default location by opening a shell, or Command Prompt on Windows,
and running the following command:

##### GNU/Linux / macOS / PowerShell:
```
cat ~/.ssh/id_rsa.pub
```
If you see a string starting with ssh-rsa you already have an SSH key pair
and you can skip the next step **Generating a new SSH key pair**
and continue onto **Copying your public SSH key to the clipboard**.
If you don't see the string or would like to generate a SSH key pair with a
custom name continue onto the next step.

### Generating a new SSH key pair

**GNU/Linux / macOS:**
```
ssh-keygen -t rsa
```

Last step, paste the **ssh public key** into the [SSH keys section](https://jenkins.io/doc/book/resources/managing/cli-adding-ssh-public-keys.png) at [http://YOUR_JENKINS_HOSTNAME/user/YOUR_USERNAME/configure](http://YOUR_JENKINS_HOSTNAME/user/YOUR_USERNAME/configure)

Now you can go to next step **Usign**

## Credentials
Alternatively you can log in using username and password. Follow the commands:

```bash
./jenkins -u USER_NAME -p PASSWORD
```

# Usage
To run the script, the syntax is:

```bash
./jenkins
```

You can specified something parameters

```none
-u  Username jenkins. Use with -p
-p  Password of the user jenkins. Use with -u
-h  help :)
-s  To specify jenkins URL. (We recommend edit script e change the var JENKINS SERVER URL)

When -u or -p is not specified, the script use ssh public key
```

# Troubleshoot
While execution of script, you can received the error below:

### Error #1
```
hudson.remoting.RequestAbortedException: java.io.StreamCorruptedException: invalid stream header: 0A0A0A0A
```

This is probably a result of **hudson.diyChunking**.

Check if diyChunking is enabled via the Script Console (JENKINS_URL/script) by running:

```
println System.getProperty("hudson.diyChunking")
```

If Result = true then read on.

You can disable diyChunking on the master by adding the Jenkins startup arg: `-Dhudson.diyChunking=false`. See How to add Java arguments to Jenkins if you need help.

#### Edit Jenkins startup arg
```
vim /etc/rc.d/init.d/jenkins
```
Edit the line:
```
JAVA_CMD="$JENKINS_JAVA_CMD $JENKINS_JAVA_OPTIONS -DJENKINS_HOME=$JENKINS_HOME -jar -Dhudson.diyChunking=false $JENKINS_WAR"
```

References: https://support.cloudbees.com/hc/en-us/articles/226235268-Jenkins-CLI-returns-invalid-stream-header-

### Error #2
```
ERROR: No such job 'JOBNAME'
```

I had the same behavior and found out that allowing anonymous read access in the [global security section](https://i.stack.imgur.com/FEO2W.png) fixed it. It is still mandatory to specify --username and --password to access the resource.

References: https://stackoverflow.com/questions/30066657/jenkins-cant-found-the-job-when-build-job-why

# Author
Rondinelli Morais, rondinellimorais@gmail.com
