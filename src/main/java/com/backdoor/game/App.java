package com.backdoor.game;

import com.backdoor.game.model.entity.Partida;
import com.backdoor.game.service.PartidaService;
import javafx.application.Application;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class App extends Application {

    private final PartidaService partidaService = new PartidaService();
    private Stage primaryStage;

    @Override
    public void start(Stage primaryStage) {
        this.primaryStage = primaryStage;
        this.primaryStage.setTitle("BACKDOOR - Menú Principal");
        mostrarMenuPrincipal();
    }

    /**
     * Muestra la pantalla del Menú Principal (crear / cargar partida).
     */
    private void mostrarMenuPrincipal() {
        Label lblTitulo = new Label("=== BACKDOOR ===");
        lblTitulo.setStyle("-fx-font-size: 24px; -fx-font-weight: bold; -fx-text-fill: #00ff00;");

        TextField txtNombre = new TextField();
        txtNombre.setPromptText("Introduce tu alias de agente...");
        txtNombre.setMaxWidth(250);
        txtNombre.setStyle("-fx-background-color: #1e1e1e; -fx-text-fill: #ffffff;");

        Button btnNuevaPartida = new Button("Iniciar Nueva Partida");
        btnNuevaPartida.setStyle("-fx-background-color: #00ff00; -fx-text-fill: #000000; -fx-font-weight: bold;");

        Label lblEstado = new Label();

        VBox root = new VBox(15);
        root.setAlignment(Pos.CENTER);
        root.setPadding(new Insets(20));
        root.setStyle("-fx-background-color: #121212;");

        // Lógica del botón
        btnNuevaPartida.setOnAction(e -> {
            String nombreJugador = txtNombre.getText().trim();
            if (nombreJugador.isEmpty()) {
                lblEstado.setText("¡Error: El alias no puede estar vacío!");
                lblEstado.setStyle("-fx-text-fill: #ff5555;");
                return;
            }

            try {
                // Invocamos al servicio (guarda en H2)
                Partida partida = partidaService.iniciarNuevaPartida(nombreJugador);

                // Transición a la pantalla de juego
                mostrarPantallaJuego(partida);

            } catch (Exception ex) {
                lblEstado.setText("Error al guardar en base de datos.");
                lblEstado.setStyle("-fx-text-fill: #ff5555;");
                ex.printStackTrace();
            }
        });

        root.getChildren().addAll(lblTitulo, txtNombre, btnNuevaPartida, lblEstado);

        Scene scene = new Scene(root, 500, 400);
        primaryStage.setScene(scene);
        primaryStage.show();
    }

    /**
     * Muestra la pantalla principal del juego una vez iniciada la partida.
     */
    private void mostrarPantallaJuego(Partida partida) {
        primaryStage.setTitle("BACKDOOR - Sesión Activa: " + partida.getNombreJugador());

        Label lblHeader = new Label("SISTEMA CONECTADO - AGENTE: " + partida.getNombreJugador().toUpperCase());
        lblHeader.setStyle("-fx-font-size: 16px; -fx-font-weight: bold; -fx-text-fill: #00ff00;");

        // Panel de estadísticas de la partida
        Label lblCreditos = new Label("Créditos: " + partida.getCreditos());
        Label lblDia = new Label("Día Actual: " + partida.getDiaActual());
        Label lblSospecha = new Label("Nivel de Sospecha: " + partida.getSospecha() + "%");
        Label lblConfianza = new Label("Confianza Nadia: " + partida.getConfianzaNadia() + "%");

        // Estilo estilo terminal para los labels
        String labelStyle = "-fx-font-size: 14px; -fx-text-fill: #00ff00;";
        lblCreditos.setStyle(labelStyle);
        lblDia.setStyle(labelStyle);
        lblSospecha.setStyle(labelStyle);
        lblConfianza.setStyle(labelStyle);

        Button btnVolver = new Button("Cerrar Sesión / Menú Principal");
        btnVolver.setOnAction(e -> mostrarMenuPrincipal());

        VBox gameRoot = new VBox(15);
        gameRoot.setAlignment(Pos.CENTER);
        gameRoot.setPadding(new Insets(20));
        gameRoot.setStyle("-fx-background-color: #0b0b0b;");

        gameRoot.getChildren().addAll(lblHeader, lblCreditos, lblDia, lblSospecha, lblConfianza, btnVolver);

        Scene gameScene = new Scene(gameRoot, 600, 450);
        primaryStage.setScene(gameScene);
    }

    public static void main(String[] args) {
        launch(args);
    }
}
