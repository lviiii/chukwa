/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.hadoop.chukwa.inputtools.log4j;


import java.io.File;
import java.io.IOException;

import org.apache.hadoop.metrics.ContextFactory;
import org.apache.hadoop.metrics.MetricsException;
import org.apache.hadoop.metrics.spi.AbstractMetricsContext;
import org.apache.hadoop.metrics.spi.OutputRecord;
import org.apache.log4j.Logger;
import org.apache.log4j.PatternLayout;
import org.json.JSONException;
import org.json.JSONObject;

public class Log4JMetricsContext extends AbstractMetricsContext {
  Logger log = Logger.getLogger(Log4JMetricsContext.class);
  Logger out = null; 
  static final Object lock = new Object();

  /* Configuration attribute names */
  protected static final String  OUTPUT_DIR_PROPERTY = "directory";
  protected static final String PERIOD_PROPERTY = "period";
  protected static final String ADD_UUID_PROPERTY = "uuid";
  

  protected static final String user = System.getProperty("user.name");
  
  protected String outputDir = null;
  protected int period = 0;
  protected boolean needUUID = false;
  
  /** Creates a new instance of FileContext */
  public Log4JMetricsContext() {
  }

  public void init(String contextName, ContextFactory factory) {
    super.init(contextName, factory);
   
    String periodStr = getAttribute(PERIOD_PROPERTY);
    if (periodStr != null) {
      int period = 0;
      try {
        period = Integer.parseInt(periodStr);
      } catch (NumberFormatException nfe) {
      }
      if (period <= 0) {
        throw new MetricsException("Invalid period: " + periodStr);
      }
      setPeriod(period);
      this.period = period;
      log.info("Log4JMetricsContext." + contextName + ".period=" + period);
    }
    
    outputDir = getAttribute(OUTPUT_DIR_PROPERTY);
    if (outputDir == null) {
      log.warn("Log4JMetricsContext." + contextName + "."+ OUTPUT_DIR_PROPERTY + " is null");
      throw new MetricsException("Invalid output directory: " + outputDir);
    }
    File fOutputDir = new File(outputDir);
    if (!fOutputDir.exists()) {
      fOutputDir.mkdirs();
    }
    log.info("Log4JMetricsContext." + contextName + "." + OUTPUT_DIR_PROPERTY +"=" + outputDir);
    
    String uuid = getAttribute(ADD_UUID_PROPERTY);
    if (uuid != null && uuid.equalsIgnoreCase("true")) {
      needUUID = true;
      log.info("Log4JMetricsContext." + contextName + "." + ADD_UUID_PROPERTY +" has been activated."); 
    }
  }

  @Override
  protected void emitRecord(String contextName, String recordName,
      OutputRecord outRec) throws IOException {
    if (out == null) {
      synchronized (lock) {
        if (out == null) {
          PatternLayout layout = new PatternLayout("%d{ISO8601} %p %c: %m%n");
          
          org.apache.hadoop.chukwa.inputtools.log4j.ChukwaDailyRollingFileAppender appender = new org.apache.hadoop.chukwa.inputtools.log4j.ChukwaDailyRollingFileAppender();
          appender.setName("chukwa.metrics." + contextName);
          appender.setLayout(layout);
          appender.setAppend(true);
          if (needUUID) {
            appender.setFile(outputDir + File.separator + "chukwa-" + user
                + "-" + contextName + "-" + System.currentTimeMillis()
                + ".log");
          } else {
            appender.setFile(outputDir + File.separator + "chukwa-" + user
                + "-" + contextName 
                + ".log");
          }

          appender.setRecordType( contextName);
          appender.setDatePattern(".yyyy-MM-dd");
          
          Logger logger = Logger.getLogger("chukwa.metrics." + contextName);
          logger.setAdditivity(false);
          logger.addAppender(appender);
          appender.activateOptions();
          out = logger;
        }
      }
    }

    JSONObject json = new JSONObject();
    try {
      json.put("contextName", contextName);
      json.put("recordName", recordName);
      json.put("chukwa_timestamp", System.currentTimeMillis());
      json.put("period", period);
      for (String tagName : outRec.getTagNames()) {
        json.put(tagName, outRec.getTag(tagName));
      }
      for (String metricName : outRec.getMetricNames()) {
        json.put(metricName, outRec.getMetric(metricName));
      }
    } catch (JSONException e) {
      log.warn("exception in Log4jMetricsContext:" , e);
    }
    out.info(json.toString());
  }

}
