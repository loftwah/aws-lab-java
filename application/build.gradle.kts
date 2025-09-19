import org.gradle.jvm.tasks.Jar
import org.springframework.boot.gradle.tasks.bundling.BootJar

plugins {
    id("org.springframework.boot") version "3.3.2"
    id("io.spring.dependency-management") version "1.1.5"
    id("com.diffplug.spotless") version "6.23.3"
    java
}

val flywayVersion = "10.22.0"
val awsSdkVersion = "2.25.49"

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<JavaCompile> {
    options.encoding = "UTF-8"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.security:spring-security-config")
    implementation("org.springframework.security:spring-security-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    implementation("org.flywaydb:flyway-core:$flywayVersion")
    implementation("org.flywaydb:flyway-database-postgresql:$flywayVersion")
    implementation(platform("software.amazon.awssdk:bom:$awsSdkVersion"))
    implementation("software.amazon.awssdk:secretsmanager")
    implementation("software.amazon.awssdk:ssm")
    implementation("software.amazon.awssdk:s3")
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation(platform("org.testcontainers:testcontainers-bom:1.20.2"))
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testCompileOnly("org.projectlombok:lombok")
    testAnnotationProcessor("org.projectlombok:lombok")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

spotless {
    java {
        target("src/**/*.java")
        googleJavaFormat("1.17.0")
        importOrder("java", "jakarta", "javax", "org", "com", "")
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

tasks.named<BootJar>("bootJar") {
    archiveFileName.set("app.jar")
}

tasks.named<Jar>("jar") {
    enabled = false
}
