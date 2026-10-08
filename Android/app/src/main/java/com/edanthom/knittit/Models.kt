package com.edanthom.knittit

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    @SerialName("id") val id: String,
    @SerialName("username") val username: String,
    @SerialName("bio") val bio: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class Project(
    @SerialName("id") val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("title") val title: String,
    @SerialName("yarn_brand") val yarnBrand: String? = null,
    @SerialName("tool_size") val toolSize: String? = null,
    @SerialName("pattern_source") val patternSource: String? = null,
    @SerialName("color_palette") val colorPalette: List<String>? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("created_at") val createdAt: String
)