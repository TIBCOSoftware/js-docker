# JasperReports Server

When evaluating JasperReports® Server, the downloads from jaspersoft.com are "bundled installers" that deploy a complete installation with Tomcat and Postgres.

The WAR file installer referred to in the JasperReports Server Installation Guide is more flexible, with repository deployments into Oracle, SQL Server, DB2 and MySQL, and app server installs into Websphere and Weblogic. Also the WAR file installer is needed to do a Docker/Kubernetes deployment - see (https://github.com/TIBCOSoftware/js-docker)

The attached Window bat and Linux/Unix sh scripts build a JasperReports Server WAR file installer based on a previously installed bundled installation.

1. Install JasperReports Server onto a machine.
2. Include the files and directory in this buildWARFileInstaller directory of the js-docker repository into the JasperReports Server install directory you set during the installation.
    * \Jaspersoft\jasperreports-server-VERSION by default on Windows.
3. Open a command line and cd into the install directory.
4. Run the scripts
    * (Windows) `.\build-WAR-file-installer`
    * (Linux/Mac) `./build-WAR-file-installer.sh` Probably need to chmod +x the .sh file
5. The WAR file installer file -TIB_js-jrs_VERSION_bin.zip - will be created.
    * There is a working directory - warfile - that can be deleted
6. Running  `./build-WAR-file-installer clean` will remove the WAR file installer file and the warfile directory
