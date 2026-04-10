package com.antigravity.devsecops.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;

class GreetingServiceTest {

    private GreetingService greetingService;

    @BeforeEach
    void setUp() {
        greetingService = new GreetingService();
    }

    @Test
    void greet_withValidName_returnsGreeting() {
        String result = greetingService.greet("Deepak");
        assertThat(result).contains("Deepak");
        assertThat(result).contains("DevSecOps Pipeline is live");
    }

    @Test
    void greet_withWorld_returnsDefaultGreeting() {
        String result = greetingService.greet("World");
        assertThat(result).isEqualTo("Hello, World! DevSecOps Pipeline is live 🚀");
    }

    @Test
    void greet_withBlankName_throwsIllegalArgumentException() {
        assertThatThrownBy(() -> greetingService.greet(""))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Name must not be blank");
    }

    @Test
    void greet_withNullName_throwsIllegalArgumentException() {
        assertThatThrownBy(() -> greetingService.greet(null))
            .isInstanceOf(IllegalArgumentException.class);
    }
}
