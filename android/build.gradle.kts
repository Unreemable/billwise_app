// يضمن توفر مستودعات Google/Maven لكل المشروعات
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// مخرجات البناء خارج مجلد android/ الافتراضي (مثل قالب Flutter الحديث)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// تأكد أن تطبيق app يُقيّم قبل التبعات
subprojects {
    project.evaluationDependsOn(":app")
}

// مهمة clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// إن واجهت رسالة تطلب classpath للـ google-services، فعّل الكتلة أدناه:
//
// buildscript {
//     repositories {
//         google()
//         mavenCentral()
//     }
//     dependencies {
//         classpath("com.google.gms:google-services:4.4.2")
//     }
// }
