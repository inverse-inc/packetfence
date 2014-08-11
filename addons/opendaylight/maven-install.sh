#! /bin/bash


TEMPORARY_DIRECTORY="$(mktemp -d)"
DOWNLOAD_TO="$TEMPORARY_DIRECTORY/maven.tgz"

echo 'Downloading Maven to: ' "$DOWNLOAD_TO"

wget -O "$DOWNLOAD_TO" http://www.eng.lsu.edu/mirrors/apache/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.tar.gz

echo 'Extracting Maven'
tar xzf $DOWNLOAD_TO -C $TEMPORARY_DIRECTORY
rm $DOWNLOAD_TO

echo 'Configuring Envrionment'

mv $TEMPORARY_DIRECTORY/apache-maven-* /usr/local/maven
echo -e 'export M2_HOME=/usr/local/maven\nexport PATH=${M2_HOME}/bin:${PATH}' > /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh

#not sure about how to set the current environment under the sudo
#sudo -u "$SUDO_USER" env  "M2_HOME=/usr/local/maven"
#sudo -u "$SUDO_USER" env "PATH=/usr/local/maven/bin:${PATH}"


echo 'The maven version: ' `mvn -version` ' has been installed.'
echo -e '\n\n!! Note you must relogin to get mvn in your path !!'
echo 'Removing the temporary directory...'
rm -r "$TEMPORARY_DIRECTORY"
echo 'Your Maven Installation is Complete.'
