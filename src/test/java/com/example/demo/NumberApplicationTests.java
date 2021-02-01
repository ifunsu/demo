package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.util.Assert;

import com.example.demo.service.NumberService;

@SpringBootTest
class NumberApplicationTests {

	@Autowired
	private NumberService numberService;
	
	@Test
	void contextLoads() {
	}

	@Test
	void testProcess() {
		String[] array = {"ad","ae","af","bd","be","bf","cd","ce","cf"};
		String[] result = this.numberService.process(new int[]{2,3});
		for (int i = 0; i < result.length; i++) {
			Assert.isTrue(array[i].equals(result[i]), "When you see this message, something goes wrong!");			
		}
	}
	
	@Test
	void testPrint() {
		String[] array = {"ad","ae","af","bd","be","bf","cd","ce","cf"};
		this.numberService.print(array);
	}
}
