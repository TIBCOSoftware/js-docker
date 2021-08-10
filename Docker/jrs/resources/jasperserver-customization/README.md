This is used to copy the customization to $CATALINA_HOME and make sure files are in the proper directory.

If you want to customize the existing file like js.config.properties or any other files which already exist in $CATALINAHOME, then make sure to copy the latest files from the container and then make the changes to it.

Example: To customize the js.config.properties file, keep the file in jasperserver-customization folder.
 
    webapps/jasperserver-pro/WEB-INF/js.config.properties 
