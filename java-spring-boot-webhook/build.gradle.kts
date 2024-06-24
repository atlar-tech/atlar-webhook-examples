plugins {
	java
	id("org.springframework.boot") version "3.3.1"
	id("io.spring.dependency-management") version "1.1.5"
	id("com.diffplug.spotless") version "6.25.0"
}

group = "com.example"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_20

repositories {
	mavenCentral()
}

dependencies {
	implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("commons-codec:commons-codec:1.17.0")
}

spotless {
  java {
    importOrder()
    removeUnusedImports()
    cleanthat()          // has its own section below
    googleJavaFormat()   // has its own section below
    formatAnnotations()  // fixes formatting of type annotations, see below
  }
}
