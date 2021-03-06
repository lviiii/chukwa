<%
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
%>
<%@ page import = "java.sql.*,java.io.*, java.util.Calendar, java.util.Date, java.text.SimpleDateFormat, java.util.*, org.apache.hadoop.chukwa.hicc.ClusterConfig, org.apache.hadoop.chukwa.hicc.TimeHandler, org.apache.hadoop.chukwa.hicc.Chart, org.apache.hadoop.chukwa.hicc.DatasetMapper, org.apache.hadoop.chukwa.database.DatabaseConfig, org.apache.hadoop.chukwa.database.Macro, org.apache.hadoop.chukwa.util.XssFilter"  %> 
<%
   XssFilter xf = new XssFilter(request);
   response.setHeader("boxId", xf.getParameter("boxId"));
   response.setContentType("text/html; chartset=UTF-8//IGNORE");
%>
<%
    String boxId=xf.getParameter("boxId");
    String render="line";
    String cluster = (String) session.getAttribute("cluster");
    String graphType = xf.getParameter("graph_type");
    int width=300;
    int height=200;
    if(request.getParameter("width")!=null) {
        width=Integer.parseInt(request.getParameter("width"));
    }
    if(request.getParameter("height")!=null) {
        height=Integer.parseInt(request.getParameter("height"));
    }
    String title = xf.getParameter("title");
    if(cluster==null) {
         cluster="demo";
    }
    String match=xf.getParameter("match");
    String group = xf.getParameter("group");
    if(match!=null) {
        String matched = (String)session.getAttribute(match);
        if(matched==null || matched.equals("")) {
            match="";
        } else {
            match=match+"="+matched;
        }
    } else {
        match="";
    }
    ClusterConfig cc = new ClusterConfig();
    String jdbc = cc.getURL(cluster);
    String path = "";
    Calendar now = Calendar.getInstance();
    long start = 0;
    long end = now.getTimeInMillis();
    String startS="";
    String endS="";
    String[] metric = xf.getParameterValues("metric");
    if(metric!=null) {
        if(metric[0].indexOf(",")>0) {
            metric = metric[0].split(",");
        }
    }
    StringBuffer metrics=new StringBuffer();
    if(metric!=null) {
        for(int i=0;i<metric.length;i++) {
            if(i==0) {
                metrics.append(metric[i]);
            } else {
                metrics.append(",");
                metrics.append(metric[i]);
            }
        }
    }
    String random = xf.getParameter("_s");
    TimeHandler time = new TimeHandler(request, (String)session.getAttribute("time_zone"));
    startS = time.getStartTimeText();
    endS = time.getEndTimeText();
    start = time.getStartTime();
    end = time.getEndTime();
    String timestamp = "timestamp";
    if(request.getParameter("normalize_time")!=null) {
       timestamp = "from_unixtime(unix_timestamp(Timestamp)-unix_timestamp(timestamp)%60) as timestamp";
    }
    if(start<=0 || end<=0) { %>
No time range specified.  Select a time range through widget preference, or use Time widget.
<%  } else {
       String timefield = "timestamp";
       String dateclause = timefield+" >= '"+startS+"' and "+timefield+" <= '"+endS+"'";
       if(request.getParameter("period")!=null && request.getParameter("period").equals("0")) {
           dateclause = "";
       }
       String minclause = "";
       if(request.getParameter("minnodes")!=null) {
           minclause="and j.NumOfMachines >= "+xf.getParameter("minnodes");
       }
       String whereclause = "";
       if(request.getParameter("user")!=null && !request.getParameter("user").equals("")) {
           whereclause="and j.UserID = "+xf.getParameter("user");
       }
       String mrtimeclause = "";
       try {
           org.apache.hadoop.chukwa.util.DriverManagerUtil.loadDriver().newInstance();
       } catch (Exception ex) {
       }
       Connection conn = null;
       Statement stmt = null;
       ResultSet rs = null;
       if(request.getParameter("group_items")!=null) {
           if(session.getAttribute(xf.getParameter("group_items"))==null) {
               session.setAttribute(xf.getParameter("group_items"),"");
           }
           int counter = 0;
           String[] group_items = ((String)session.getAttribute(xf.getParameter("group_items"))).split(",");
           String appendDomain = xf.getParameter("append_domain");
           if(appendDomain==null) {
               appendDomain="";
           }
           if(group_items!=null) {
               for(String item : group_items) {
                   if(counter!=0) {
                       match = match + " or ";
                   } else {
                       match = "(";
                   }
                   match = match + group + " = '"+ item+ appendDomain +"'";
                   counter++;
               }
               if(!match.equals("")) {
                   match = match + ")";
               }
           }
       }
       String table = (String)xf.getParameter("table");
       if(table==null) {
           table = "cluster_system_metrics";
       }
       if(request.getParameter("group_override")!=null) {
           group=xf.getParameter("group_override");
       }
       String[] tables = null;
       DatabaseConfig dbc = new DatabaseConfig();
       tables = dbc.findTableNameForCharts(table,start,end);
       ArrayList<String> labels = new ArrayList<String>();
       TreeMap<String, TreeMap<String, Double>> dataMap = new TreeMap<String, TreeMap<String, Double>>();
       for(String tmpTable : tables) {
           String query = null;
           if(!dateclause.equals("") && !match.equals("")) {
               dateclause=" and "+dateclause;
           }
           if(group!=null) {
               query = "select "+timestamp+","+group+","+metrics+" from "+tmpTable+" where "+match+dateclause+" order by timestamp";
           } else {
               query = "select "+timestamp+","+metrics+" from "+tmpTable+" where "+match+dateclause+" order by timestamp";
           }
           DatasetMapper dataFinder = new DatasetMapper(jdbc);
           boolean groupBySecondColumn=false;
           if(group!=null) {
               groupBySecondColumn=true;
           }
           boolean odometer=false;
           if(request.getParameter("find_slope")!=null) {
               odometer=true;
           }
           if(request.getParameter("query")!=null) {
               query = request.getParameter("query");
               Macro mp = new Macro(start,end,query, request);
               query = mp.toString();
           }
           dataFinder.execute(query,groupBySecondColumn,odometer,graphType);
           List<String> tmpLabels = dataFinder.getXAxisMap();
           TreeMap<String, TreeMap<String, Double>> tmpDataMap = dataFinder.getDataset();
           for(int t=0;t<tmpLabels.size();t++) {
               labels.add(tmpLabels.get(t));
           }
           Iterator<String> ki = tmpDataMap.keySet().iterator();
           while(ki.hasNext()) {
               String ts = ki.next();
               if(dataMap.containsKey(ts)) {
                   TreeMap<String, Double> newTree = dataMap.get(ts);
                   for(String s : tmpDataMap.get(ts).keySet()) {
                       newTree.put(s,tmpDataMap.get(ts).get(s));
                   }
                   dataMap.put(ts,newTree);
               } else {
                   dataMap.put(ts,tmpDataMap.get(ts));
               }
           } 
       }
       if(dataMap.size()!=0) {
           if(request.getParameter("render")!=null) {
               render=xf.getParameter("render");
           }
           Chart c = new Chart(request);
           c.setYAxisLabels(false);
           if(request.getParameter("x_label")!=null && xf.getParameter("x_label").equals("on")) {
               c.setXAxisLabels(true);
           } else {
               c.setXAxisLabels(false);
           }
           c.setYAxisLabel("");
           if(request.getParameter("x_axis_label")!=null) {
               c.setXAxisLabel(xf.getParameter("x_axis_label"));
           } else {
               c.setXAxisLabel("Time");
           }
           if(title!=null) {
               c.setTitle(title);
           } else {
               c.setTitle(metrics.toString());
           }
           if(request.getParameter("y_axis_max")!=null) {
               double max = Double.parseDouble(xf.getParameter("y_axis_max"));
               c.setYMax(max);
           }
           if(request.getParameter("display_percentage")!=null) {
	       c.setDisplayPercentage(true);
	   }
           if(request.getParameter("legend")!=null && xf.getParameter("legend").equals("off")) {
               c.setLegend(false);
           }
           c.setGraphType(graphType);
           c.setXLabelsRange(labels);
           c.setSize(width,height);
           c.setDataSet(render,dataMap);
           if(metric!=null && group==null) {
               c.setSeriesOrder(metric);
           }
           out.println(c.plot());
        }
    }
%>
