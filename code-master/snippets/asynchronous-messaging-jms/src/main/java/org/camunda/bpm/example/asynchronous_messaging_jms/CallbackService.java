package org.camunda.bpm.example.asynchronous_messaging_jms;

import java.util.HashMap;
import java.util.Map;

import javax.annotation.Resource;
import javax.ejb.Stateless;
import javax.inject.Inject;
import javax.inject.Named;
import javax.jms.Connection;
import javax.jms.MessageProducer;
import javax.jms.Queue;
import javax.jms.QueueConnectionFactory;
import javax.jms.Session;
import javax.jms.TextMessage;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;

import org.camunda.bpm.engine.HistoryService;
import org.camunda.bpm.engine.RuntimeService;
import org.camunda.bpm.engine.history.HistoricActivityInstance;
import org.camunda.bpm.engine.runtime.Execution;
import org.camunda.bpm.engine.runtime.ProcessInstance;

@Named
@Stateless
public class CallbackService {

  @Inject
  private RuntimeService runtimeService;
  
  @Inject
  private HistoryService historyService;
  
  @PersistenceContext
  private EntityManager entityManager;
  
  @Resource(mappedName = "java:/queue/test")
  private Queue queue;

  @Resource(mappedName = "java:/JmsXA")
  private QueueConnectionFactory connectionFactory;  
  
  public void receiveCallback(String correlationKey, Object payload) {
    String messageName = "serviceExecutionCompleted";

//    Execution execution = runtimeService.createExecutionQuery()
//            .processVariableValueEquals("correllationId", correlationKey)
//            .singleResult();
//
//    Execution execution = runtimeService.createExecutionQuery()
//            .processInstanceBusinessKey(correlationKey)
//            .singleResult();
//    
//    runtimeService.signal(execution.getId(), variables);
//    runtimeService.messageEventReceived(messageName, execution.getId());
	  

    // UUID in Process Variable
//    Map<String,Object> correlationKeys = new HashMap<String, Object>();
//	  correlationKeys.put("correllationId", correlationKey);
//	  Map<String, Object> variables = new HashMap<String, Object>();
//    variables.put("payload", payload);
//    runtimeService.correlateMessage(messageName, correlationKeys);
	  
    // UUID in Process Variable
	  runtimeService.createMessageCorrelation(messageName)
	  	.processInstanceVariableEquals("correllationId", correlationKey)
//	  	.processInstanceActivityId("receiveTaskId") // not implemented
	  	.setVariable("payload", payload)
	  	.correlate();

    // Combination of Process Instance (see above) and Activity ID
    String receiveTaskId;
    Execution execution = runtimeService.createExecutionQuery()
      .messageEventSubscriptionName(messageName)
      .processInstanceBusinessKey(correlationKey) // process instance
      .activityId(receiveTaskId) // token
      .singleResult();
    runtimeService.messageEventReceived(messageName, execution.getId());
    
    
    // Business Key
	  String businessKey = correlationKey; // TODO: Retrieve business key from message
	  runtimeService.createMessageCorrelation(messageName)
	    .processInstanceBusinessKey(businessKey)
      .setVariable("payload", payload)
      .correlate();
	  
	  ProcessInstance processInstance = runtimeService.createProcessInstanceQuery()
      .processInstanceBusinessKey(correlationKey) // requires unique business key
      .singleResult();
    
    HistoricActivityInstance historicActivityInstance = historyService.createHistoricActivityInstanceQuery()
      .processInstanceId(processInstance.getId())
      .activityId("SendTask_1")
      .singleResult();
    
    runtimeService.messageEventReceived(messageName, historicActivityInstance.getExecutionId(), processVariables);

    // Business Key
    runtimeService.createMessageCorrelation(messageName)
      .processInstanceBusinessKey(correlationKey) // requires unique business key
      .setVariable("payload", payload)
      .correlate();
  
  }
  
  public void triggerAsynchronousCallback(String asynchronousCorrelationKey) {
    try {
      Connection connection = connectionFactory.createConnection();
      Session session = connection.createSession(true, Session.AUTO_ACKNOWLEDGE);
      MessageProducer producer = session.createProducer(queue);
      TextMessage message = session.createTextMessage(asynchronousCorrelationKey);
      producer.send(message);
      producer.close();
      session.close();
      connection.close();
    }
    catch (Exception ex) {
      throw new RuntimeException("Could not send JMS message", ex);
    }
  }

}
