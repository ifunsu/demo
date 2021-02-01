package com.example.demo.service;

import java.util.List;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import com.google.common.collect.Lists;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class NumberServiceImpl implements NumberService, InitializingBean {

	// 电话按键
	private String[] digitals = { "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz" };

	@Override
	public void afterPropertiesSet() throws Exception {
		log.info("===Stage 1:");
		this.print(this.process(new int[]{2,3}));
		this.print(this.process(new int[]{9}));
		log.info("===Stage 2:");
		this.print(this.process(new int[]{2,38,76,54,9,10}));
	}
	
	@Override
	public void print(String[] array) {
		log.info("结果长度为：{}", array.length);
		for (String s : array) {
			log.info(s);
		}		
	}
	
	@Override
	public String[] process(int[] array) {
		List<Integer> list = Lists.newArrayList();
		for (int i : array) {
			list.add(i);
		}
		return this.processArray(list);
	}

	// 处理数组
	private String[] processArray(List<Integer> list) {
		if (list.size() == 1) {
			return this.processSingle(list.get(0));
		} else {
			// 不止一个则递归调用
			Integer one = list.get(0);
			String[] theOne = this.processSingle(one);
			List<Integer> next = list.subList(1, list.size());
			String[] nextResults = this.processArray(next);
			// 当前节点与下级结果交叉叠加
			String[] results = new String[theOne.length * nextResults.length];
			for (int i = 0; i < theOne.length; i++) {
				for (int j = 0, size = nextResults.length; j < size; j++) {
					results[i * size + j] = theOne[i] + nextResults[j];
				}
			}
			return results;
		}
	}

	// 处理单个数字的情况
	private String[] processSingle(Integer digital) {
		if (digital > 9) {
			int higher = digital / 10;
			int lower = digital % 10;
			List<Integer> l = Lists.newArrayList();
			l.add(higher);
			l.add(lower);
			return this.processArray(l);
		} else {
			String result = this.digitals[digital];
			if (StringUtils.hasLength(result)) {
				return this.split(result);
			} else {
				return new String[] { result };
			}
		}
	}

	// 单个数字进行拆分字母
	private String[] split(String s) {
		String[] results = new String[s.length()];
		for (int i = 0; i < results.length; i++) {
			results[i] = s.charAt(i) + "";
		}
		return results;
	}

}
