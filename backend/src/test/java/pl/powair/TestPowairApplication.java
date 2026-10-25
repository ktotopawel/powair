package pl.powair;

import org.springframework.boot.SpringApplication;

public class TestPowairApplication {

	public static void main(String[] args) {
		SpringApplication.from(PowairApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
