## Importing to a JasperReports Server repository

1. Create an 'import.properties' file in a directory, with each line containing parameters
for individual imports from export zip files and/or directories. See the JasperReports Server
Administration Guide - section: "Importing from the Command Line" for the options.

```
# Comment lines are ignored, as are empty lines

# Server settings
--input-zip BS-server-settings-export.zip

# Repository import
--input-zip Bikeshare-JRS-export.zip

# Import from a directory
--input-dir some-sub-directory

# Organization import. Org has to be created before running this import
--input-zip Bikeshare_org_user_export.zip --organization Bikeshare
```

1. Place the ZIP files and/or directories into the same directory as the
`import.properties`.

1. Run the JasperReports Server image, defining and passing into the command
one or more volumes where the import.properties
and the exports are stored.

And do either:

  1. Use a database instance running in Docker. Note the network and DB_HOST settings.
  ```
  docker run --rm \
    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/import \
	--network js-docker_default -e DB_HOST=jasperserver_pro_repository  \
	--name jasperserver-pro-import \
	jasperserver-pro:X.X.X import /usr/local/share/jasperserver-pro/import
  ```
  1. Use an external repository database. Note the DB_HOST setting.
  ```
  docker run --rm \
    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/import \
	-e DB_HOST=domain.or.IP.where.database.is  \
	--name jasperserver-import \
	jasperserver-pro:X.X.X import /usr/local/share/jasperserver-pro/import
  ```
  
After an import run, the import.properties file is renamed in the volume as `import-done.properties`.

Note that, as of JasperReports 7.2.0 at least, there is no way to import a organization
export.zip at the highest level (root) without first creating the organization via the
JasperReports Server user interface or REST.
