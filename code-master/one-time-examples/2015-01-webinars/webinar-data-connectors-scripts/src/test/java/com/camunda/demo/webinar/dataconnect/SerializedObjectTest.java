package com.camunda.demo.webinar.dataconnect;

import static org.camunda.bpm.engine.test.assertions.ProcessEngineAssertions.assertThat;
import static org.camunda.bpm.engine.test.assertions.ProcessEngineAssertions.init;
import static org.camunda.bpm.engine.test.assertions.ProcessEngineAssertions.processEngine;
import static org.camunda.bpm.engine.test.assertions.ProcessEngineTests.complete;
import static org.camunda.bpm.engine.test.assertions.ProcessEngineTests.task;
import static org.junit.Assert.assertEquals;

import java.util.Map;

import org.camunda.bpm.engine.runtime.ProcessInstance;
import org.camunda.bpm.engine.test.Deployment;
import org.camunda.bpm.engine.test.ProcessEngineRule;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.Variables;
import org.camunda.bpm.engine.variable.Variables.SerializationDataFormats;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;

/**
 * Test case starting an in-memory database-backed Process Engine.
 */
public class SerializedObjectTest {

  @Rule
  public ProcessEngineRule rule = new ProcessEngineRule();

  private static final String PROCESS_DEFINITION_KEY = "webinar-data-connectors-scripts";

  // enable more detailed logging
  static {
    // LogUtil.readJavaUtilLoggingConfigFromClasspath(); // process engine
    // LogFactory.useJdkLogging(); // MyBatis
  }

  @Before
  public void setup() {
    init(rule.getProcessEngine());
  }

  /**
   * Just tests if the process definition is deployable.
   */
  @Test
  @Deployment(resources = "process.bpmn")
  public void testParsingAndDeployment() {
    // nothing is done here, as we just want to check for exceptions
    // duringzdeployment
  }

  @Test
  @Deployment(resources = "process.bpmn")
  public void testRejected() throws Exception {
    CreditorApplication application = new CreditorApplication();
    application.setBankAccountNumber("123456");
    application.setBankIdentifierCode("10070024"); // Deutsche Bank Berlin
    application.setCompany("Acme Inc");
    application.setEmail("br@camunda.com");
   
    
    Map<String, Object> variables = Variables.createVariables()
        .putValue("application", application);
//        .putValueTyped("application", Variables.objectValue(application).serializationDataFormat(SerializationDataFormats.XML).create());
    
    ProcessInstance pi = processEngine().getRuntimeService().startProcessInstanceByKey(PROCESS_DEFINITION_KEY, variables);
    
    // what happens with "application" in the database?
    // lets inspect it
    org.h2.tools.Server.createTcpServer( "-tcp", "-tcpAllowOthers").start();
    // --> now we can inspect it - just set a breakpoint in the next line:
    // - JDBC URL:  jdbc:h2:tcp://localhost:9092/mem:camunda
    
    assertThat(pi).task().hasDefinitionKey("userTaskApproveCreditor");
    
    assertEquals("Deutsche Bank Privat und Geschäftskunden F 700", 
        (String)processEngine().getRuntimeService().getVariable(pi.getId(), "bankName"));

    application = (CreditorApplication)processEngine().getRuntimeService().getVariable(pi.getId(), "application");
    assertEquals("Deutsche Bank Privat und Geschäftskunden F 700", application.getBankName());

    assertThat(pi).variables().containsEntry("bankName", "Deutsche Bank Privat und Geschäftskunden F 700");
    
    application.setApproved(false);
    complete(task(), Variables.createVariables().putValue("application", application));

    assertThat(pi).isEnded().hasPassed("EndEventCreditorRejected");   
  }
  

  @Test
  @Deployment(resources = "process.bpmn")
  public void testApprove() throws Exception {
    CreditorApplication application = new CreditorApplication();
    application.setBankAccountNumber("123456");
    application.setBankIdentifierCode("10070024"); // Deutsche Bank Berlin
    application.setCompany("Acme Inc");
    application.setEmail("br@camunda.com");
    application.setApproved(true);
    
    VariableMap variables = Variables.createVariables()
        //.putValue("application", application);
        .putValueTyped("application", Variables.objectValue(application).serializationDataFormat(SerializationDataFormats.JSON).create());
    
    ProcessInstance pi = processEngine().getRuntimeService().startProcessInstanceByKey(PROCESS_DEFINITION_KEY, variables);
    
    assertThat(pi).task().hasDefinitionKey("userTaskApproveCreditor");    
    complete(task());

    assertThat(pi).isEnded().hasPassed("EndEventCreditorCreated");
  }  
}
