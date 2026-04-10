package com.antigravity.devsecops.service;

import org.springframework.stereotype.Service;

@Service
public class GreetingService {

    public String greet(String name) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Name must not be blank");
        }
        return "Hello, " + name + "! DevSecOps Pipeline is live 🚀";
    }
}
