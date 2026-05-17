package com.sunsetwan.deckstring

import kotlin.test.Test
import kotlin.test.assertEquals

class KmpBuildSkeletonTest {
    @Test
    fun exposesModuleNameForBuildValidation() {
        assertEquals("DeckStringDecoder", KmpBuildSkeleton.moduleName)
    }
}
