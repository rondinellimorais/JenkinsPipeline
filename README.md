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

## Credentials
Alternatively you can log in using username and password
