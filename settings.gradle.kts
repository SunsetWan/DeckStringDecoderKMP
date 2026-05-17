pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }

    val useLocalSkie = providers.gradleProperty("skie.useLocal")
        .map(String::toBoolean)
        .getOrElse(false)

    if (useLocalSkie) {
        val localSkiePath = providers.gradleProperty("skie.localPath")
            .getOrElse("/Users/sunset/HS_APP/SKIE")
        includeBuild(localSkiePath)
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "DeckStringDecoder"

include(":deckstring")
