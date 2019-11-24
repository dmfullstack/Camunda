package com.camunda.consulting.asyncJoins.nonarquillian;

import java.util.List;

import org.apache.ibatis.logging.LogFactory;
import org.camunda.bpm.engine.ProcessEngineException;
import org.camunda.bpm.engine.impl.util.LogUtil;
import org.camunda.bpm.engine.runtime.Incident;
import org.camunda.bpm.engine.runtime.Job;
import org.camunda.bpm.engine.runtime.ProcessInstance;
import org.camunda.bpm.engine.test.ProcessEngineRule;
import org.camunda.bpm.engine.test.Deployment;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;

import static org.camunda.bpm.engine.test.assertions.ProcessEngineTests.*;
import static org.junit.Assert.*;

/**
 * Test case starting an in-memory database-backed Process Engine.
 */
public class AsyncJoinTest {

  @Rule
  public ProcessEngineRule rule = new ProcessEngineRule();

  private static final String PROCESS_DEFINITION_KEY = "async-joins";
  private static final String MULTI_INSTANCE = "multi-instance";
  private static final String MULTI_INSTANCE_RECURSIVE = "multi-instance-recursive";
  private static final String PARALLEL = "parallel-process";
  private static final String PARALLEL_SUBPROCESS = "parallel-subprocess";


  // enable more detailed logging
  static {
    LogUtil.readJavaUtilLoggingConfigFromClasspath(); // process engine
    LogFactory.useJdkLogging(); // MyBatis
  }
  
  @Before
  public void setup() {
    init(rule.getProcessEngine());
  }

  /**
   * Just tests if the process definition is deployable.
   */
  @Test
  @Deployment(resources = {"process.bpmn", "multiInstanceProcess.bpmn", 
      "multiInstanceRecursive.bpmn", "parallelProcess.bpmn", "parallelSubprocess.bpmn"})
  public void testParsingAndDeployment() {
    // nothing is done here, as we just want to check for exceptions during deployment
  }
  
  @Test
  @Deployment(resources = "process.bpmn")
  public void startWithParallelOrSplit() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PROCESS_DEFINITION_KEY, withVariables("allTransitions", true));
    assertThat(pi).hasPassed("ServiceTask_1", "ServiceTask_2");
    assertThat(pi).isWaitingAt("InclusiveGateway_2");
  }
  
  @Test
  @Deployment(resources = "process.bpmn")
  public void continueAtParallelJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PROCESS_DEFINITION_KEY, withVariables("allTransitions", true));
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      execute(job);
    }
    assertThat(pi).hasPassed("InclusiveGateway_2");
    assertThat(pi).isEnded();
    assertEquals(1, historyService().createHistoricActivityInstanceQuery().activityId("EndEvent_1").count());
  }
  
  @Test
  @Deployment(resources = "multiInstanceProcess.bpmn")
  public void startMultiInstanceAsyncJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(MULTI_INSTANCE);
    assertThat(pi).hasPassed("ServiceTask_1");
    assertThat(pi).isWaitingAt("EndEvent_2");
  }
  
  @Test
  @Deployment(resources = "multiInstanceProcess.bpmn")
  public void continueMultiInstanceAsyncEnd() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(
        MULTI_INSTANCE,
        withVariables("continue", "continue"));
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      execute(job);
    }
    assertThat(pi).hasPassed("EndEvent_2", "ServiceTask_2");
    assertThat(pi).isEnded();
  }
  
  @Test
  @Deployment(resources = "parallelProcess.bpmn")
  public void startParallelAsyncJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PARALLEL);
    assertThat(pi).hasPassed("ServiceTask_1", "ServiceTask_2");
    assertThat(pi).isWaitingAt("ParallelGateway_2");
  }

  @Test
  @Deployment(resources = "parallelProcess.bpmn")
  public void continueParallelAsyncJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PARALLEL);
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      execute(job);
    }
    assertThat(pi).hasPassed("ParallelGateway_2", "ServiceTask_3");
    assertThat(pi).isEnded();
  }
  
  @Test
  @Deployment(resources = "multiInstanceRecursive.bpmn")
  public void startInnermostMultiInstanceAsyncJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(MULTI_INSTANCE_RECURSIVE);
    assertThat(pi).hasPassed("ServiceTask_1");
    assertThat(pi).isWaitingAt("EndEvent_2");
  }
  
  @Test
  @Deployment(resources = "parallelSubprocess.bpmn")
  public void startParallelSubprocessAsyncJoin() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PARALLEL_SUBPROCESS);
    assertThat(pi).hasPassed("ServiceTask_1", "ServiceTask_2");
    assertThat(pi).isWaitingAt("ParallelGateway_2");
  }
  
  @Test
  @Deployment(resources = "parallelSubprocess.bpmn")
  public void continueToMultiInstanceEnd() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PARALLEL_SUBPROCESS);
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      execute(job);
    }
    assertThat(pi).hasPassed("ParallelGateway_2");
    assertThat(pi).isWaitingAt("EndEvent_1");
  }
  
  @Test
  @Deployment(resources = "parallelSubprocess.bpmn")
  public void continueParallelMultiInstanceEnd() {
    ProcessInstance pi = runtimeService().startProcessInstanceByKey(PARALLEL_SUBPROCESS);
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      execute(job);
    }
    // contine EndEvent_1
    jobs = jobQuery().list();
    assertThat(jobs).hasSize(2); // loopCardinality is 2
    for (Job job : jobs) {      
      execute(job);
    }
    assertThat(pi).hasPassed("ServiceTask_3");
    assertThat(pi).isEnded();
  }
  
  @Test
  @Deployment(resources = "multiInstanceProcess.bpmn")
  public void runIntoIncident() {
    runtimeService().startProcessInstanceByKey(MULTI_INSTANCE);
    List<Job> jobs = jobQuery().list();
    for (Job job : jobs) {
      try {
        execute(job);
      } catch (ProcessEngineException e) {
        // Do nothing
      }
    }
    for (int i = 0; i < 3; i++) {      
      Job job = jobQuery().singleResult();
      try {
        execute(job);
      } catch (ProcessEngineException e) {
        // Do nothing
      }
    }
    List<Incident> incidents = runtimeService().createIncidentQuery().list();
    assertThat(incidents).isNotEmpty();
  }
}
