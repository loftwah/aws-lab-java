package com.deanlofts.awslabjava.application.controller;

import com.deanlofts.awslabjava.application.config.AppProperties;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LandingController {

    private final AppProperties appProperties;

    public LandingController(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @GetMapping(path = "/", produces = MediaType.TEXT_HTML_VALUE)
    public String index() {
        return """
            <html lang=\"en\">
              <head>
                <meta charset=\"utf-8\" />
                <title>AWS Lab Java Demo</title>
                <style>
                  body { font-family: Arial, sans-serif; margin: 2rem; background: #f4f6fb; color: #223; }
                  header { margin-bottom: 1.5rem; }
                  .badge { display: inline-block; padding: 0.2rem 0.6rem; border-radius: 0.4rem; background: #0052cc; color: #fff; font-size: 0.85rem; }
                  section { background: #fff; padding: 1.5rem; border-radius: 0.6rem; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
                  footer { margin-top: 1.5rem; font-size: 0.8rem; color: #777; }
                </style>
              </head>
              <body>
                <header>
                  <h1>AWS Lab Java Demo</h1>
                  <span class=\"badge\">""" + appProperties.getDeploymentTarget() + """</span>
                </header>
                <section>
                  <p>Welcome to Dean Lofts' AWS Lab Java showcase. This demo exercises the platform foundations including ECS, EC2, RDS, networking, and CI/CD.</p>
                  <ul>
                    <li>Runtime owner: """ + appProperties.getOwner() + """</li>
                    <li>Deployment target: """ + appProperties.getDeploymentTarget() + """</li>
                    <li>Explore the health endpoint at <code>/healthz</code></li>
                    <li>Interact with sample CRUD APIs under <code>/api/v1/widgets</code> (authenticated)</li>
                  </ul>
                </section>
                <footer>
                  <p>&copy; """ + java.time.Year.now() + """ Dean Lofts – AWS Lab Java Demo.</p>
                </footer>
              </body>
            </html>
            """;
    }
}
