# TIBCO JasperReports&reg; Server for Docker
# Additional options

# Table of contents

1. [Clustering](#clustering)

# Clustering

JasperReports Server can be clustered and load balanced. See the JasperReports Server Ultimate Guide for details.

A JasperReports Server cluster running in containers is made up of:

- A load balancer or proxy server
  - Must implement "sticky sessions" or "session affinity"
  - Apache, Nginx, HAProxy and Kubernetes Load balancers are examples of load balancers that can be used in container environments.

- One or more JasperReports Server containers
  - Configured to use a cache replication service
  
- Cache replication service
  - Java Messaging Service (JMS) works well in containers
  - Java RMI is another cache replication option for JasperReports Server. RMI is difficult to configure in containers, since it leverages UDP broadcast
  - ActiveMQ is easily deployable in containers
  
- A repository database
  - Shared by all JasperReports Server containers in the cluster

## Example Clustering Configuration

Note that this configuration does not implement partial session replication. as outlined in the JasperReports Server Ultimate Guide.

**cluster-docker-compose.yml**

_ActiveMQ_

```
  activemq:
    # Runs ActiveMQ JMS on the default port 61616
    image: rmohr/activemq:5.15.9-alpine

```

_HAProxy_

```
  haproxy:
    image: haproxy:1.8
    ports:
        - 80:80
        - 9999:9999
    volumes:
        - /path/to/haproxy:/usr/local/etc/haproxy
```

**haproxy.cfg**

Refer to the directory this file is in, in the `/path/to/haproxy` volume mount.

``` 
frontend myApp
	bind *:80
	use_backend jasperserver-pro

backend jasperserver-pro
	balance roundrobin
	cookie JSESSIONID prefix nocache
	server web01 jrs-pro-1:8080 check cookie web01
	server web02 jrs-pro-2:8080 check cookie web02
```

This section in the haproxy.cfg presents a single URL on port 80 and load balances across 2 JasperReports Servers, launched via the `cluster-docker-compose.yml`.

**jms-cluster-cache.zip**

To be put in `/path/to/jasperserver-pro/customization/directory` to be loaded into the JasperReports Server containers, within the JasperReports Server WAR.

Contains ehcache configuration files that point to a JMS provider.

**.cluster_env**

Usual environment variables, with one addition for caching.

`JAVA_OPTS=-Djasperserver.cache.jms.provider=tcp://activemq:61616`

The jasperserver.cache.jms.provider system property is referred to within the ehcache configuration files.

Must be of the form: `tcp://<JMS provider domain or IP>:<JMS port on provider>`

In the example `JAVA_OPTS` above:

- `activemq` is the domain of the ActiveMQ JMS service defined in `cluster-docker-compose.yml`
- `61616` is the default ActiveMQ JMS port
