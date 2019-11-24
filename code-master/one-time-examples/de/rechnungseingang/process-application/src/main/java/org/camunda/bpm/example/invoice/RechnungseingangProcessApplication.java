package org.camunda.bpm.example.invoice;

import static com.camunda.demo.environment.DefaultFilter.FILTER_GruppenAufgaben;
import static com.camunda.demo.environment.DefaultFilter.FILTER_MeineAufgaben;
import static com.camunda.demo.environment.DefaultFilter.FILTER_Ueberfaellig;
import static com.camunda.demo.environment.DefaultFilter.FILTER_Wiedervorlage;
import static com.camunda.demo.environment.DefaultFilter.FILTER_alleAufgaben;
import static com.camunda.demo.environment.DefaultFilter.FILTER_management;
import static com.camunda.demo.environment.UserDataGenerator.addFilterGroupAuthorization;
import static com.camunda.demo.environment.UserDataGenerator.addFilterUserAuthorization;
import static com.camunda.demo.environment.UserDataGenerator.addGroup;
import static com.camunda.demo.environment.UserDataGenerator.addUser;
import static com.camunda.demo.environment.UserDataGenerator.createGrantGroupAuthorization;
import static com.camunda.demo.environment.UserDataGenerator.createGrantUserAuthorization;

import org.camunda.bpm.application.PostDeploy;
import org.camunda.bpm.application.ProcessApplication;
import org.camunda.bpm.application.impl.ServletProcessApplication;
import org.camunda.bpm.engine.ProcessEngine;
import org.camunda.bpm.engine.authorization.Permission;
import org.camunda.bpm.engine.authorization.Permissions;
import org.camunda.bpm.engine.authorization.Resources;

import com.camunda.demo.environment.ProcessApplicationDemoSetup;

@ProcessApplication
public class RechnungseingangProcessApplication extends ServletProcessApplication {

  @PostDeploy
  public void generateProcessInstances(ProcessEngine engine) {
    ProcessApplicationDemoSetup.executeDefaultSetup(engine, "rechnungseingang", getReference()); 
    
    addUser(engine, "desi", "desi", "Desi", "Ree");
    addGroup(engine, "assistenz", "Team Asssistenz", "desi");
    addFilterGroupAuthorization(engine, "assistenz", FILTER_MeineAufgaben, FILTER_GruppenAufgaben, FILTER_Wiedervorlage, FILTER_Ueberfaellig);

    addUser(engine, "lars", "lars", "Lars", "Lustig");
    addGroup(engine, "buchhaltung", "Buchhaltung", "lars");
    addFilterGroupAuthorization(engine, "buchhaltung", FILTER_MeineAufgaben, FILTER_GruppenAufgaben);

    addUser(engine, "anne", "anne", "Anne", "Wichtig");
    addGroup(engine, "management", "Management", "anne");
    addFilterUserAuthorization(engine, "anne", FILTER_MeineAufgaben, FILTER_GruppenAufgaben, FILTER_management, FILTER_alleAufgaben);

    createGrantGroupAuthorization(engine, //
        new String[] { "assistenz", "buchhaltung" }, //
        new Permission[] { Permissions.CREATE }, //
        Resources.PROCESS_INSTANCE,
        new String[] { "*" });
    createGrantGroupAuthorization(engine, //
        new String[] { "assistenz", "buchhaltung" }, //
        new Permission[] { Permissions.READ, Permissions.CREATE_INSTANCE, Permissions.READ_HISTORY, Permissions.READ_INSTANCE }, //
        Resources.PROCESS_DEFINITION, //
        new String[] { "rechnungseingang" });
    createGrantUserAuthorization(engine, //
        new String[] { "anne" }, new Permission[] { Permissions.READ, Permissions.READ_INSTANCE, Permissions.READ_HISTORY }, //
        Resources.PROCESS_DEFINITION, //
        new String[] { "rechnungseingang" });
    createGrantUserAuthorization(engine, //
        new String[] { "anne" }, //
        new Permission[] { Permissions.READ, Permissions.UPDATE }, //
        Resources.TASK,
        new String[] { "*" });
    createGrantUserAuthorization(engine, //
        new String[] { "anne" }, //
        new Permission[] { Permissions.ACCESS }, //
        Resources.APPLICATION, //
        new String[] { "cockpit" });
  }

}
