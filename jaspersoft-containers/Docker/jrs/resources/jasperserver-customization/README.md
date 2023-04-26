This folder is used to apply customizations to $CATALINA_HOME and its subdirectories.

If you want to customize any file which already exists in $CATALINAHOME, or any JasperReports® Server file, for example, js.config.properties, then make sure to copy them into a proper directory structure under jasperserver-customization. Then all the contents of the jasperserver-customization folder will be copied into $CATALINAHOME.

Example: To customize the js.config.properties file, copy the edited file into such directory structure under jasperserver-customization:

webapps/jasperserver-pro/WEB-INF/js.config.properties

conf/server.xml has been already customized to improve the Tomcat performance. Bellow listed attributes that have been already changed, this file can be edited if there is a need for other customizations


| Attribute Name |  Value |
|----------------|-----------|
| protocol | org.apache.coyote.http11.Http11NioProtocol|
| maxThreads | 300 |
| connectionTimeout | 60000 |
| maxConnections | 10000 |
