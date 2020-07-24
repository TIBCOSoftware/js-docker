## Exporting to a JasperReports Server repository

1. Create an 'export.properties' file in a directory, with each line containing parameters for individual imports: zip files and/or directories. See the `JasperReports Server Administration Guide` - section: "Exporting from the Command Line" for the options.

```console
# Comment lines are ignored, as are empty line

# Server setting

--output-zip BS-server-settings-export.zip  --include-server-settings

# Repository export

--output-zip Bikeshare-JRS-export.zip --uris /public/Bikeshare_demo

# Repository export

--output-dir some-sub-directory

# Organization export. The organization has to be created before running this import.

--output-zip Bikeshare_org_user_export.zip --organization Bikeshar
```

1. Run the JasperReports Server image with the export command defining and passing into the command in one or more volumes where the `export.properties` is and the exports are to be stored. And do either:

  1. Use existing database running in Docker. 

  ```console
  docker run --rm 

    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/export 

    -v /path/to/a/volume-license:/usr/local/share/jasperserver-pro/license -v /path/to/a/volume-keystore:/usr/local/share/jasperserver-pro/keystore

    --network js-docker_default -e DB_HOST=jasperserver_pro_repository  

    --name jasperserver-pro-export 

    jasperserver-pro-cmdline:X.X.X export /usr/local/share/jasperserver-pro/export
  ```
