package com.donation.app.ui.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donation.app.data.Categories
import com.donation.app.data.PostType
import com.donation.app.ui.components.EmptyState
import com.donation.app.ui.components.LoadingBox
import com.donation.app.ui.components.PostCard
import com.donation.app.ui.components.appChipColors

/** CU-19 · Feed con filtros, y acceso a CU-14 y CU-11 desde el botón "Publicar". */
@Composable
fun FeedScreen(
    onOpenPost: (Long) -> Unit,
    onPublish: (PostType) -> Unit,
    vm: FeedViewModel = viewModel()
) {
    val posts by vm.posts.collectAsStateWithLifecycle()
    val type by vm.type.collectAsStateWithLifecycle()
    val category by vm.category.collectAsStateWithLifecycle()
    var menuOpen by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            Text(
                "Publicaciones",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 8.dp)
            )

            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    FilterChip(
                        selected = type == null,
                        onClick = { vm.selectType(null) },
                        label = { Text("Todas") },
                        colors = appChipColors()
                    )
                }
                items(PostType.entries) { t ->
                    FilterChip(
                        selected = type == t,
                        onClick = { vm.selectType(t) },
                        label = { Text(if (t == PostType.ARTICULO) "Artículos" else "Necesidades") },
                        colors = appChipColors()
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(Categories.all) { c ->
                    FilterChip(
                        selected = category == c,
                        onClick = { vm.selectCategory(c) },
                        label = { Text(c) },
                        colors = appChipColors()
                    )
                }
            }

            val list = posts
            when {
                list == null -> LoadingBox()
                list.isEmpty() -> EmptyState("No hay publicaciones con estos filtros.")
                else -> LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentPadding = PaddingValues(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 96.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(list, key = { it.id }) { post ->
                        PostCard(
                            post = post,
                            isMine = post.authorId == vm.userId,
                            onClick = { onOpenPost(post.id) }
                        )
                    }
                }
            }
        }

        Box(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
        ) {
            ExtendedFloatingActionButton(
                onClick = { menuOpen = true },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Publicar") },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            )
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text("Donar un artículo") },
                    onClick = {
                        menuOpen = false
                        onPublish(PostType.ARTICULO)
                    }
                )
                DropdownMenuItem(
                    text = { Text("Publicar una necesidad") },
                    onClick = {
                        menuOpen = false
                        onPublish(PostType.NECESIDAD)
                    }
                )
            }
        }
    }
}
