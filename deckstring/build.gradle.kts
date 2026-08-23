import org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework
import co.touchlab.skie.configuration.EnumInterop
import co.touchlab.skie.configuration.FunctionInterop
import co.touchlab.skie.configuration.SealedInterop
import org.gradle.api.DefaultTask
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.bundling.Zip
import org.gradle.process.ExecOperations
import java.io.ByteArrayOutputStream
import javax.inject.Inject

plugins {
    kotlin("multiplatform")
    id("co.touchlab.skie")
}

abstract class ComputeSwiftPMChecksumTask @Inject constructor(
    private val execOperations: ExecOperations
) : DefaultTask() {
    @get:InputFile
    abstract val artifact: RegularFileProperty

    @get:OutputFile
    abstract val checksumFile: RegularFileProperty

    @TaskAction
    fun compute() {
        val checksumOutput = ByteArrayOutputStream()
        execOperations.exec {
            commandLine("swift", "package", "compute-checksum", artifact.get().asFile.absolutePath)
            standardOutput = checksumOutput
        }

        val checksum = checksumOutput.toString().trim()
        val outputFile = checksumFile.get().asFile
        outputFile.parentFile.mkdirs()
        outputFile.writeText("$checksum\n")
        logger.lifecycle("SwiftPM checksum for ${artifact.get().asFile.name}: $checksum")
    }
}

kotlin {
    val deckStringDecoderXcFramework = XCFramework("DeckStringDecoder")

    jvm()
    iosArm64()
    iosSimulatorArm64()
    iosX64()

    targets.withType<KotlinNativeTarget>().configureEach {
        binaries.framework {
            baseName = "DeckStringDecoder"
            isStatic = true
            binaryOption("bundleId", "com.sunsetwan.DeckStringDecoder")
            deckStringDecoderXcFramework.add(this)
        }
    }

    sourceSets {
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
    }
}

skie {
    build {
        produceDistributableFramework()
        freeSwiftCompilerArgs.addAll(
            listOf(
                "-Xfrontend",
                "-module-interface-preserve-types-as-written"
            )
        )
    }

    features {
        group("com.sunsetwan.deckstring") {
            EnumInterop.Enabled(false)
            FunctionInterop.FileScopeConversion.Enabled(false)
            SealedInterop.Enabled(false)
        }
    }

    analytics {
        enabled.set(false)
    }
}

val releaseXcFrameworkName = "DeckStringDecoder.xcframework"
val releaseXcFrameworkZipName = "$releaseXcFrameworkName.zip"
val swiftPMBinaryDirectory = layout.buildDirectory.dir("swiftpm-binary")
val releaseXcFrameworkDirectory = layout.buildDirectory.dir("XCFrameworks/release/$releaseXcFrameworkName")
val releaseXcFrameworkChecksumFile = layout.buildDirectory.file("swiftpm-binary/$releaseXcFrameworkZipName.checksum")
val consumerArtifactDirectory = rootProject.layout.projectDirectory.dir("swiftpm-binary/consumer/Artifacts")
val iosSimulatorDestination = providers.environmentVariable("IOS_SIMULATOR_DESTINATION")
    .orElse("platform=iOS Simulator,name=iPhone 17")

val zipDeckStringDecoderReleaseXCFramework = tasks.register<Zip>("zipDeckStringDecoderReleaseXCFramework") {
    group = "distribution"
    description = "Zip the release DeckStringDecoder.xcframework for SwiftPM binary target distribution."

    dependsOn("assembleDeckStringDecoderReleaseXCFramework")
    from(releaseXcFrameworkDirectory) {
        into(releaseXcFrameworkName)
    }

    archiveFileName.set(releaseXcFrameworkZipName)
    destinationDirectory.set(swiftPMBinaryDirectory)
    includeEmptyDirs = false
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}

val computeDeckStringDecoderReleaseChecksum = tasks.register<ComputeSwiftPMChecksumTask>("computeDeckStringDecoderReleaseChecksum") {
    group = "distribution"
    description = "Compute the SwiftPM checksum for the release DeckStringDecoder.xcframework.zip artifact."

    val zipFile = zipDeckStringDecoderReleaseXCFramework.flatMap { it.archiveFile }

    dependsOn(zipDeckStringDecoderReleaseXCFramework)
    artifact.set(zipFile)
    checksumFile.set(releaseXcFrameworkChecksumFile)
}

val syncDeckStringDecoderSwiftPMConsumerArtifact = tasks.register<Copy>("syncDeckStringDecoderSwiftPMConsumerArtifact") {
    group = "verification"
    description = "Copy the SwiftPM binary zip artifact into the local consumer package."

    dependsOn(zipDeckStringDecoderReleaseXCFramework)
    from(zipDeckStringDecoderReleaseXCFramework.flatMap { it.archiveFile })
    into(consumerArtifactDirectory)
}

tasks.register("prepareDeckStringDecoderSwiftPMBinaryRelease") {
    group = "distribution"
    description = "Build the release XCFramework, zip it, compute checksum, and prepare the local SwiftPM consumer artifact."

    dependsOn(
        zipDeckStringDecoderReleaseXCFramework,
        computeDeckStringDecoderReleaseChecksum,
        syncDeckStringDecoderSwiftPMConsumerArtifact
    )
}

tasks.register<Exec>("verifyDeckStringDecoderSwiftPMConsumer") {
    group = "verification"
    description = "Run the local SwiftPM binary consumer tests on iOS Simulator."

    dependsOn("prepareDeckStringDecoderSwiftPMBinaryRelease")
    workingDir = rootProject.layout.projectDirectory.dir("swiftpm-binary/consumer").asFile
    commandLine(
        "xcodebuild",
        "-scheme",
        "DeckStringDecoderBinaryConsumer",
        "-destination",
        iosSimulatorDestination.get(),
        "-derivedDataPath",
        ".build/xcode-derived-data",
        "test"
    )
}
