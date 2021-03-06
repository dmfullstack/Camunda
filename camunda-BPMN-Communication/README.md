#References

Este proyecto se centra en los eventos de mensaje en BPMN. Está pensado para compilarse como war y desplegarse en un servidor de camunda. En el war se incluyen los diagramas y las calases java que implementan las tareas.

This video is view in 
[7 Tutorial: Process Communication](https://www.youtube.com/watch?v=8SYEc3dHnM4 "7 Tutorial: Process Communication")

# Camunda BPM Process Application
A Process Application for [Camunda BPM](http://docs.camunda.org).

This project has been generated by the Maven archetype:

[camunda-archetype-servlet-war-7.11.1](http://docs.camunda.org/latest/guides/user-guide/#process-applications-maven-project-templates-archetypes).

## Show me the important parts!

![BPMN Process](src/main/resources/manage_forum.png)

![BPMN Process](src/main/resources/Team_support.png)

## How does it work?

## How to use it?

### Unit Test
You can run the JUnit test [InMemoryH2Test](src/main/resources/archetype-resources/src/test/java/InMemoryH2Test.java) in your IDE or using:
```bash
mvn clean test
```

### Deployment in Spring Boot

-	curso básico

    https://www.youtube.com/playlist?list=PLJG25HlmvsOUnCziyJBWzcNh7RM5quTmv

-	started de camunda con spring-boot, para generar un proyecto de camunda con spring-boot nuevo

    http://start.camunda.com/

-	doc oficial de camunda para empezar

    https://docs.camunda.org/get-started/spring-boot/


### Deployment to an Application Server
You can also build and deploy the process application to an application server.
For an easy start you can download Apache Tomcat with a pre-installed Camunda
from our [Download Page](https://camunda.com/download/).

#### Manually
1. Build the application using:
```bash
mvn clean package
```
2. Copy the *.war file from the `target` directory to the deployment directory
of your application server e.g. `tomcat/webapps` or `wildfly/standalone/deployments`.
For a faster 1-click (re-)deployment see the alternatives below.

#### Apache Tomcat (using Maven AntRun Plugin)
1. First copy the file `build.properties.example` to `build.properties`
2. Edit the `build.properties` file and put the path to your Tomcat into `deploy.tomcat.dir`.
3. Build and deploy the process application using:
```bash
mvn clean package antrun:run
```

Alternatively, you can also copy the `build.properties` file to `${user.home}/.camunda/build.properties`
to have a central configuration that works with all projects generated by the
[Camunda Maven Archetypes](http://docs.camunda.org/latest/guides/user-guide/#process-applications-maven-project-templates-archetypes) e.g. the [examples provided by the Camunda Consulting Team](https://github.com/camunda-consulting/code).

#### Apache Tomcat (using Tomcat Maven Plugin)
1. Create a user in Tomcat with the role `manager-script`.
2. Add the user's credentials to the `tomcat7-maven-plugin` configuration in the [pom.xml](pom.xml) file.
3. Build and deploy the process application using:
```bash
mvn clean tomcat7:deploy
```

#### Wildfly (using Wildfly Maven Plugin)
1. Build and deploy the process application using:
```bash
mvn clean wildfly:deploy
```

#### JBoss AS7 (using JBoss AS Maven Plugin)
1. Build and deploy the process application using:
```bash
mvn clean jboss-as:deploy
```

#### Ant (and Maven)
1. First copy the file `build.properties.example` to `build.properties`
2. Edit the `build.properties` file and put the path to your application server inside it.
3. Build and deploy the process application using:
```bash
ant deploy.tomcat
```
or
```bash
ant deploy.jboss
```

Alternatively, you can also copy the `build.properties` file to `${user.home}/.camunda/build.properties`
to have a central configuration that works with all projects generated by the
[Camunda Maven Archetypes](http://docs.camunda.org/latest/guides/user-guide/#process-applications-maven-project-templates-archetypes) e.g. the [examples provided by the Camunda Consulting Team](https://github.com/camunda-consulting/code).

### Run and Inspect with Tasklist and Cockpit
Once you deployed the application you can run it using
[Camunda Tasklist](http://docs.camunda.org/latest/guides/user-guide/#tasklist)
and inspect it using
[Camunda Cockpit](http://docs.camunda.org/latest/guides/user-guide/#cockpit).



### Execute the example

-    Instanciar el proceso "manage_forum", mediante perición rest


```http
Type: Post

localhost:8080/engine-rest/message

Body : mandamos el siguiente JSON

{
  "messageName" : "QuestionCreated",
  "businessKey" : "1",
  "processVariables" : {
    "question" : 
			{
				"value" : "que pregunto 3?", 					"type": "String"
 			}	
	}
}
```


-    Mandar mensaje indicando que sabe la respuesta:

```http
Type: Post

localhost:8080/engine-rest/message

Body : mandamos el siguiente JSON

{
  "messageName" : "Knows",
  "businessKey" : "1",
  "processVariables" : {
    "confidence" : 
			{
				"value" : "10",
				"type": "String"
 			}	
	}
}
```

-    Mandar mensaje indicando que NO sabe la respuesta:

```http
Type: Post

localhost:8080/engine-rest/message

Body : mandamos el siguiente JSON

{
  "messageName" : "HasNoIdea",
  "businessKey" : "1"
}
```


-    Mandar mensaje indicando que la respuesta ha sido editada:

```http
Type: Post

localhost:8080/engine-rest/message

Body : mandamos el siguiente JSON

{
  "messageName" : "QuestionHasBeenEdited",
  "businessKey" : "1",
  "processVariables" : {
    "question" : 
			{
				"value" : "how far away is the sun",
				"type": "String"
 			}	
	}
}
```

-    lanzar señal de tarabajo importante

```http
Type: Post

localhost:8080/engine-rest/signal

Body : mandamos el siguiente JSON

{
  "name": "ImportantWork",
  "variables": {
    "newTimePeriodInMonth": {
      "value": 24
    }
  }
}
```



## Environment Restrictions
Built and tested against Camunda BPM version 7.11.0.

## Known Limitations

## License
[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

<!-- HTML snippet for index page
  <tr>
    <td><img src="snippets/camunda-BPMN-Communication/src/main/resources/process.png" width="100"></td>
    <td><a href="snippets/camunda-BPMN-Communication">Camunda BPM Process Application</a></td>
    <td>A Process Application for [Camunda BPM](http://docs.camunda.org).</td>
  </tr>
-->
<!-- Tweet
New @Camunda example: Camunda BPM Process Application - A Process Application for [Camunda BPM](http://docs.camunda.org). https://github.com/camunda-consulting/code/tree/master/snippets/camunda-BPMN-Communication
-->