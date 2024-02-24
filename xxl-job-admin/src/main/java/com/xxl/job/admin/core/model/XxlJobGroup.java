package com.xxl.job.admin.core.model;

import com.xxl.job.admin.util.SpringContextUtil;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Created by xuxueli on 16/9/30.
 */
public class XxlJobGroup {

    private int id;
    private String appname;
    private String title;
    private int addressType;        // 执行器地址类型：0=自动注册、1=手动录入
    private String addressList;     // 执行器地址列表，多地址逗号分隔(手动录入)
    private Date updateTime;

    // registry list
    private List<String> registryList;  // 执行器地址列表(系统注册)
    public List<String> getRegistryList() {
        if (addressList!=null && !addressList.trim().isEmpty()) {
            String newAddressList = addressList;
            // address 执行器管理填入的机器地址 http://ip:port 这里自定义兼容 lb://servicename地址
            if(addressList.startsWith("lb://")){
                String serviceName = addressList.replace("lb://","");
                DiscoveryClient discoveryClient = SpringContextUtil.getBean(DiscoveryClient.class);
                List<ServiceInstance> instances = discoveryClient.getInstances(serviceName);
                List<String> uriList = instances.stream().map(a -> a.getUri().toString()).collect(Collectors.toList());
                if(!uriList.isEmpty()) {
                    StringBuilder strBuf = new StringBuilder();
                    uriList.forEach(e -> strBuf.append(e).append(','));
                    newAddressList = strBuf.deleteCharAt(strBuf.length() - 1).toString();
                } else {
                    newAddressList = "";
                }
            }
            registryList = StringUtils.hasText(newAddressList) ? new ArrayList<>(Arrays.asList(newAddressList.split(",")))
                    : new ArrayList<>(0);
        }
        return registryList;
    }

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getAppname() {
        return appname;
    }

    public void setAppname(String appname) {
        this.appname = appname;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public int getAddressType() {
        return addressType;
    }

    public void setAddressType(int addressType) {
        this.addressType = addressType;
    }

    public String getAddressList() {
        return addressList;
    }

    public Date getUpdateTime() {
        return updateTime;
    }

    public void setUpdateTime(Date updateTime) {
        this.updateTime = updateTime;
    }

    public void setAddressList(String addressList) {
        this.addressList = addressList;
    }

}
